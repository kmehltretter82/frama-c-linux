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
open Basic_blocks

module type Builtin = sig
  module Hashtbl: Datatype.Hashtbl
  type override_key = Hashtbl.key

  val function_name: string
  val well_typed_call: exp list -> bool
  val key_from_call: exp list -> override_key
  val retype_args: override_key -> exp list -> exp list
  val generate_prototype: override_key -> (string * typ)
  val generate_spec: override_key -> fundec -> location -> funspec
  val args_for_original: override_key -> fundec -> exp list
end

module type Internal_builtin = sig
  include Builtin
  module Enabled: Parameter_sig.Bool
  val get_override: override_key -> fundec
  val get_globals: location -> global list
  val mark_as_computed:  ?project:Project.t -> unit -> unit
end

module Make_internal_builtin (B: Builtin) = struct
  include B
  module Enabled = Options.NewBuiltin (B)
  module Cache = State_builder.Hashtbl (B.Hashtbl) (Cil_datatype.Fundec)
      (struct
        let size = 5
        let dependencies = [Ast.self]
        let name = "Builtins." ^ B.function_name
      end)

  let create_and_add key =
    let (name, typ) = B.generate_prototype key in
    let fd = Basic_blocks.prepare_definition name typ in
    let loc  = Cil_datatype.Location.unknown in
    let open Globals.Functions in
    let open Extlib in
    let ret_var = match Cil.getReturnType fd.svar.vtype with
      | t when Cil.isVoidType t -> None
      | t -> Some (Cil.makeLocalVar fd "__retres" t)
    in
    let call =
      let orig = get_vi (find_by_name function_name) in
      let args = B.args_for_original key fd in
      Instr(call_function (opt_map Cil.var ret_var) orig args)
    in
    let ret = Return ( (opt_map Cil.evar ret_var), loc) in
    fd.sbody <-
      { (Cil.mkBlock (List.map Cil.mkStmt [ call ; ret ])) 
        with blocals = list_of_opt ret_var } ;
    File.must_recompute_cfg fd ;
    Cache.add key fd

  let get_override key =
    try
      Cache.find key
    with Not_found ->
      create_and_add key ;
      Cache.find key

  let get_globals location =
    let finalize key fd =
      let spec = B.generate_spec key fd location in
      Globals.Functions.replace_by_definition spec fd location ;
      Cil_types.GFun(fd, location)
    in
    Cache.fold (fun k vi l -> (finalize k vi) :: l) []

  let mark_as_computed = Cache.mark_as_computed
end

let base : (string, (module Internal_builtin)) Hashtbl.t = Hashtbl.create 17

let register (module B: Builtin) =
  let module Internal_builtin = Make_internal_builtin(B) in
  Hashtbl.add base B.function_name (module Internal_builtin)

let mark_as_computed () =
  let mark_as_computed _ builtin =
    let module B = (val builtin: Internal_builtin) in B.mark_as_computed ()
  in
  Hashtbl.iter mark_as_computed base

let get_globals loc =
  let get_globals _ builtin =
    let module B = (val builtin: Internal_builtin) in B.get_globals loc
  in
  Hashtbl.fold (fun k v l -> (get_globals k v) @ l) base []

let find_stdlib_attr fct =
  if not (Cil.hasAttribute "fc_stdlib" fct.vattr) then raise Not_found

let replace_call (fct, args) =
  try
    find_stdlib_attr fct ;
    let builtin = Hashtbl.find base fct.vname in
    let module B = (val builtin: Internal_builtin) in
    if B.well_typed_call args then
      let key = B.key_from_call args in
      let fundec = B.get_override key in
      let new_args = B.retype_args key args in
      (fundec.svar), new_args
    else begin
      Options.warning ~current:true "Ignore call: not well typed" ;
      (fct, args)
    end
  with
  | Not_found -> (fct, args)

class visitor = object(_)
  inherit Visitor.frama_c_inplace

  method! vfile _ =
    let after f =
      let loc = Cil.CurrentLoc.get() in
      let globals = get_globals loc in
      f.globals <- globals @ f.globals ;
      mark_as_computed () ;
      Ast.mark_as_changed () ;
      Ast.mark_as_grown () ;
      File.reorder_ast () ;
      f
    in
    Cil.DoChildrenPost after

  method! vfunc f =
    let kf = Globals.Functions.get f.svar in
    if Options.Kfs.is_empty () || Options.Kfs.mem kf then
      Cil.DoChildren
    else
      Cil.SkipChildren

  method! vinst = function
    | Call(_) | Local_init(_, ConsInit(_, _, Plain_func), _) ->
      let change = function
        | [ Call(r, ({ enode = Lval((Var f), NoOffset) } as e), args, loc) ] ->
          let f, args = replace_call (f, args) in
          [ Call(r, { e with enode = Lval((Var f), NoOffset) }, args, loc) ]
        | [ Local_init(r, ConsInit(f, args, Plain_func), loc) ] ->
          let f, args = replace_call (f, args) in
          [ Local_init(r, ConsInit(f, args, Plain_func), loc) ]
        | _ -> assert false
      in
      Cil.DoChildrenPost change
    | _ -> Cil.DoChildren
end

let transform file =
  let filter _ b =
    let module B = (val b : Internal_builtin) in
    if B.Enabled.get () then Some b else None
  in
  Hashtbl.filter_map_inplace filter base ;
  Visitor.visitFramacFile (new visitor) file
