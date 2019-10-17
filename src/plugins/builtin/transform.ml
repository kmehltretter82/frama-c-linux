(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Builtin_builder

let base : (string, (module Builtin)) Hashtbl.t = Hashtbl.create 17

let register (module G: Generator_sig) =
  let module Builtin = Make_builtin(G) in
  Hashtbl.add base G.function_name (module Builtin)

let mark_as_computed () =
  let mark_as_computed _ builtin =
    let module B = (val builtin: Builtin) in B.mark_as_computed ()
  in
  Hashtbl.iter mark_as_computed base

let get_kfs () =
  let get_kfs _ builtin =
    let module B = (val builtin: Builtin) in
    let res = B.get_kfs () in
    res
  in
  Hashtbl.fold (fun k v l -> (get_kfs k v) @ l) base []

let find_stdlib_attr fct =
  if not (Cil.hasAttribute "fc_stdlib" fct.vattr) then raise Not_found

module VISet = Cil_datatype.Varinfo.Hptset

class transformer = object(self)
  inherit Visitor.frama_c_inplace

  val introduced_builtins = ref VISet.empty
  val used_builtin_last_kf = Queue.create ()

  method! vfile _ =
    let post f =
      Ast.mark_as_changed () ;
      Ast.mark_as_grown () ;
      mark_as_computed () ;
      f
    in
    Cil.DoChildrenPost post

  method! vglob_aux _ =
    let post g =
      let loc = Cil.CurrentLoc.get() in
      let folding l fd =
        if VISet.mem fd.svar !introduced_builtins then l
        else begin
          introduced_builtins := VISet.add fd.svar !introduced_builtins ;
          GFun (fd, loc) :: l
        end
      in
      Queue.fold folding g used_builtin_last_kf
    in
    Cil.DoChildrenPost post

  method! vfunc f =
    let kf = Globals.Functions.get f.svar in
    if not (Options.Kfs.is_set ()) || Options.Kfs.mem kf then
      Cil.DoChildren
    else
      Cil.SkipChildren

  method private replace_call (fct, args) =
    try
      find_stdlib_attr fct ;
      let builtin = Hashtbl.find base fct.vname in
      let module B = (val builtin: Builtin) in
      if B.Enabled.get () then
        if B.well_typed_call args then
          let key = B.key_from_call args in
          let fundec = B.get_override key in
          let new_args = B.retype_args key args in
          Queue.add fundec used_builtin_last_kf ;
          (fundec.svar), new_args
        else begin
          Options.warning ~current:true "Ignore call: not well typed" ;
          (fct, args)
        end
      else (fct, args)
    with
    | Not_found -> (fct, args)

  method! vinst = function
    | Call(_) | Local_init(_, ConsInit(_, _, Plain_func), _) ->
      let change = function
        | [ Call(r, ({ enode = Lval((Var f), NoOffset) } as e), args, loc) ] ->
          let f, args = self#replace_call (f, args) in
          [ Call(r, { e with enode = Lval((Var f), NoOffset) }, args, loc) ]
        | [ Local_init(r, ConsInit(f, args, Plain_func), loc) ] ->
          let f, args = self#replace_call (f, args) in
          [ Local_init(r, ConsInit(f, args, Plain_func), loc) ]
        | _ -> assert false
      in
      Cil.DoChildrenPost change
    | _ -> Cil.DoChildren
end

let validate_property p =
  Property_status.emit Options.emitter ~hyps:[] p Property_status.True

let compute_preconditions_statuses kf =
  let stmt = Kernel_function.find_first_stmt kf in
  let _ = Kernel_function.find_all_enclosing_blocks stmt in
  match stmt.skind with
  | Instr (Call(_, { enode = Lval ((Var fct), NoOffset) }, _, _)) ->
    let called_kf = Globals.Functions.get fct in
    Statuses_by_call.setup_all_preconditions_proxies called_kf ;
    let reqs = Statuses_by_call.all_call_preconditions_at
        ~warn_missing:true called_kf stmt
    in
    List.iter (fun (_, p) -> validate_property p) reqs ;
  | _ -> assert false

let compute_statuses_all_calls () =
  let kfs = get_kfs () in
  List.iter compute_preconditions_statuses kfs ;

  let module Kfs = Kernel_function.Hptset in
  let open Property in
  let kfs = List.fold_left (fun s kf -> Kfs.add kf s) Kfs.empty kfs in
  let validate_if_builtin_post ip =
    match ip with
    (* Constracts of generated functions *)
    | IPPredicate { ip_kf=kf ; ip_kind=PKEnsures _ }
    | IPAssigns { ias_kf=kf }
    | IPFrom { if_kf=kf }
      when Kfs.mem kf kfs ->
      validate_property ip
    | _ -> ()
  in
  Property_status.iter validate_if_builtin_post


let transform file =
  Visitor.visitFramacFile (new transformer) file ;
  compute_statuses_all_calls ()
