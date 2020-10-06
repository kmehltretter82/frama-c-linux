(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

module Fct = Cil_datatype.Kf.Set

module TargetKfs =
  State_builder.Set_ref
    (Fct)
    (struct
      let dependencies = [ Ast.self ]
      let name = "WpTarget.TargetKfs"
    end)

let calls_visitor callees = object(self)
  inherit Visitor.frama_c_inplace
  method private add kf =
    callees := Fct.add kf !callees

  method! vinst = function
    | Call(_, { enode = Lval(Var vi, NoOffset) }, _, _)
    | Local_init (_,ConsInit(vi,_,_),_) ->
        let kf = Globals.Functions.get vi in
        self#add kf ;
        Cil.SkipChildren
    | Call _ ->
        begin match Extlib.opt_map Dyncall.get self#current_stmt with
          | Some (Some (_, l)) -> List.iter self#add l
          | _ -> ()
        end ;
        Cil.SkipChildren
    | _ -> Cil.SkipChildren
end

module Callees =
  State_builder.Hashtbl
    (Cil_datatype.Kf.Hashtbl)
    (Fct)
    (struct
      let dependencies = [Ast.self]
      let name = "WpTarget.Callees"
      let size = 17
    end)

(** Note: we add the kf received in parameter in the set only if it has a
    definition (and thus if it does not have one, we add nothing as it has
    no visible callee).

    This prevent to warn on prototypes that have a contract but are unused. If
    the function is used, it will be added to the set via its caller(s) if they
    are under verification.
*)
let with_callees kf =
  if Kernel_function.has_definition kf then begin
    let set = ref (Fct.singleton kf) in
    ignore (Visitor.visitFramacKf (calls_visitor set) kf) ;
    !set
  end else
    Fct.empty

let with_callees = Callees.memo with_callees

let add_with_callees kf =
  Fct.iter TargetKfs.add (with_callees kf)

exception Found

let check_properties behaviors props kf =
  let check_ip ip =
    let names = WpPropId.user_prop_names ip in
    if props = [] || WpPropId.are_selected_names props names then raise Found
  in
  let check_with f bhv p = check_ip (f kf Kglobal bhv p) in
  let check_bhv_requires bhv =
    List.iter (check_with Property.ip_of_requires bhv) bhv.b_requires
  in
  let check_bhv_ensures bhv =
    List.iter (check_with Property.ip_of_ensures bhv) bhv.b_post_cond
  in
  let opt_check = function None -> () | Some p -> check_ip p in
  let check_bhv_assigns kf kinstr bhv =
    opt_check (Property.ip_assigns_of_behavior kf kinstr ~active:[] bhv)
  in
  let check_bhv_allocation kf kinstr bhv =
    opt_check (Property.ip_allocation_of_behavior kf kinstr ~active:[] bhv)
  in
  let check_bhv reqs behaviors kf kinstr bv =
    if behaviors = [] || List.mem bv.b_name behaviors then begin
      if reqs then check_bhv_requires bv ;
      check_bhv_assigns kf kinstr bv ;
      check_bhv_allocation kf kinstr bv ;
      check_bhv_ensures bv
    end
  in
  let check_code behaviors =
    let stmts =
      try (Kernel_function.get_definition kf).sallstmts
      with Kernel_function.No_Definition -> []
    in
    let for_a_bhv l = match behaviors with
      | [] -> true
      | bhvs -> List.exists (fun e -> List.mem e bhvs) l
    in
    let check stmt _ ca =
      match ca.annot_content with
      | AAssert(fors, _) | AInvariant(fors, _, _) when for_a_bhv fors ->
          check_ip (Property.ip_of_code_annot_single kf stmt ca)
      | AVariant _v ->
          check_ip (Property.ip_of_code_annot_single kf stmt ca)
      | AAssigns(fors, _) when for_a_bhv fors ->
          opt_check (Property.ip_assigns_of_code_annot kf (Kstmt stmt) ca)
      | AAllocation(fors, a) when for_a_bhv fors ->
          let kind = Property.Id_loop ca in
          opt_check (Property.ip_of_allocation kf (Kstmt stmt) kind a)
      | AStmtSpec(fors, s) ->
          if for_a_bhv fors then raise Found ;
          List.iter (check_bhv true behaviors kf (Kstmt stmt)) s.spec_behavior
      | _ -> ()
    in
    let check_call stmt =
      let check_callee kf =
        let kf_behaviors = Annotations.behaviors kf in
        List.iter
          begin fun b ->
            if behaviors = [] || List.mem b.b_name behaviors then
              List.iter (check_with Property.ip_of_requires b) b.b_requires
          end
          kf_behaviors
      in
      match stmt.skind with
      | Instr (Call(_, { enode = Lval(Var vi, NoOffset) }, _, _))
      | Instr (Local_init (_,ConsInit(vi,_,_),_)) ->
          check_callee (Globals.Functions.get vi)
      | Instr (Call _) ->
          begin match Dyncall.get stmt with
            | None -> ()
            | Some (_, l) -> List.iter check_callee l
          end
      | _ -> ()
    in
    let check_stmt stmt =
      check_call stmt ;
      Annotations.iter_code_annot (check stmt) stmt
    in
    List.iter check_stmt stmts
  in
  let check_funbhv _ bv = check_bhv false behaviors kf Kglobal bv in
  Annotations.iter_behaviors check_funbhv kf ;
  check_code behaviors

let add_with_behaviors behaviors props kf =
  if behaviors = [] && props = [] then
    add_with_callees kf
  else begin
    try check_properties behaviors props kf
    with Found -> add_with_callees kf
  end

let compute model =
  let insert_rte kf =
    if Wp_parameters.RTE.get () then
      WpRTE.generate model kf
  in
  let behaviors = Wp_parameters.Behaviors.get() in
  let props = Wp_parameters.Properties.get () in
  let add_kf kf =
    insert_rte kf ;
    add_with_behaviors behaviors props kf
  in
  let functions = Wp_parameters.Functions.get () in
  let skipped   = Wp_parameters.SkipFunctions.get () in
  let open Globals.Functions in
  if Fct.is_empty functions then
    if Fct.is_empty skipped then iter add_kf
    else iter (fun kf -> if Fct.mem kf skipped then () else add_kf kf)
  else Fct.iter add_kf (Fct.diff functions skipped)

let compute model =
  if not (TargetKfs.is_computed ()) then begin
    compute model ;
    TargetKfs.mark_as_computed ()
  end

let iter = TargetKfs.iter
