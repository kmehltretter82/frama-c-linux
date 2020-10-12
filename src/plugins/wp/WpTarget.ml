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

let get_called_stmt stmt =
  match stmt.skind with
  | Instr (Call(_, fct, _, _)) ->
      begin match Kernel_function.get_called fct with
        | Some kf -> [kf]
        | None -> Extlib.(opt_conv [] (opt_map snd (Dyncall.get stmt)))
      end
  | Instr (Local_init (_,ConsInit(vi,_,_),_)) -> [ Globals.Functions.get vi ]
  | _ -> []

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
  try
    let stmts = (Kernel_function.get_definition kf).sallstmts in
    let fold s stmt =
      List.fold_left (fun s kf -> Fct.add kf s) s (get_called_stmt stmt)
    in
    List.fold_left fold (Fct.singleton kf) stmts
  with Kernel_function.No_Definition -> Fct.empty

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
      List.iter check_callee (get_called_stmt stmt)
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
  Wp_parameters.iter_kf add_kf

let compute model =
  if not (TargetKfs.is_computed ()) then begin
    compute model ;
    TargetKfs.mark_as_computed ()
  end

let iter = TargetKfs.iter
