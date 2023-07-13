(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Cil_datatype


module Tbl =
  Cil_state_builder.Kinstr_hashtbl
    (Function_Froms)
    (struct
      let name = "Callwise dependencies"
      let size = 17
      let dependencies = [ Eva.Analysis.self ]
    end)
let () = From_parameters.ForceCallDeps.set_output_dependencies [Tbl.self]

let merge_call_froms table callsite froms =
  try
    let current = Kinstr.Hashtbl.find table callsite in
    let new_froms = Function_Froms.join froms current in
    Kinstr.Hashtbl.replace table callsite new_froms
  with Not_found ->
    Kinstr.Hashtbl.add table callsite froms

(** State for the analysis of one function call *)
type from_state = {
  current_function: Kernel_function.t (** Function being analyzed *);
  value_initial_state: Cvalue.Model.t (** State of Eva at the beginning of
                                          the call *);
  table_for_calls: Function_Froms.t Kinstr.Hashtbl.t
(** State of the From plugin for each statement containing a function call
    in the body of [current_function]. Updated incrementally each time
    Value analyses such a statement *);
}

(** The state of the callwise From analysis. Only the top of this callstack
    is accessed. New calls are pushed on the stack when Value starts the
    analysis of a function, and popped when the analysis finishes. This
    stack is manually synchronized with Value's callstack. *)
let call_froms_stack : from_state list ref = ref []

let record_callwise_dependencies_in_db call_site froms =
  try
    let previous = Tbl.find call_site in
    Tbl.replace call_site (Function_Froms.join previous froms)
  with Not_found -> Tbl.add call_site froms

let call_for_individual_froms _callstack current_function value_initial_state call_type =
  if From_parameters.ForceCallDeps.get () then begin
    match call_type with
    | `Def | `Reuse ->
      let table_for_calls = Kinstr.Hashtbl.create 7 in
      call_froms_stack :=
        { current_function; value_initial_state; table_for_calls } ::
        !call_froms_stack
    | `Builtin | `Spec -> ()
  end

let end_record call_stack froms =
  let current_function_value, call_site = Eva.Callstack.top_call call_stack in
  record_callwise_dependencies_in_db call_site froms;
  (* pop + record in top of stack the froms of function that just finished *)
  match !call_froms_stack with
  | {current_function} :: ({table_for_calls = table} :: _ as tail) ->
    if current_function_value != current_function then
      From_parameters.fatal "calldeps %a != %a@."
        Kernel_function.pretty current_function
        Kernel_function.pretty current_function_value;
    call_froms_stack := tail;
    merge_call_froms table call_site froms

  | _ ->  (* the entry point, probably *)
    Tbl.mark_as_computed ();
    call_froms_stack := []


module MemExec =
  State_builder.Hashtbl
    (Datatype.Int.Hashtbl)
    (Function_Froms)
    (struct
      let size = 17
      let dependencies = [Tbl.self]
      let name = "From.Callwise.MemExec"
    end)

let compute_call_from_value_states current_function states =
  let module To_Use = struct
    let get_from_call _f callsite =
      let { table_for_calls } = List.hd !call_froms_stack in
      try Kinstr.Hashtbl.find table_for_calls (Cil_types.Kstmt callsite)
      with Not_found -> raise From_compute.Call_did_not_take_place

    let stmt_request stmt =
      Eva.Results.in_cvalue_state
        (try Stmt.Hashtbl.find states stmt
         with Not_found -> Cvalue.Model.bottom)

    let keep_base kf base =
      let fundec = Kernel_function.get_definition kf in
      not (Base.is_formal_or_local base fundec)

    let cleanup_and_save _kf froms = froms
  end
  in
  let module Callwise_Froms = From_compute.Make(To_Use) in
  Callwise_Froms.compute_and_return current_function


let record_for_individual_froms callstack cur_kf initial_state value_res =
  if From_parameters.ForceCallDeps.get () then begin
    let current_function, call_site = Eva.Callstack.top_call callstack in
    let register_from froms =
      record_callwise_dependencies_in_db call_site froms;
      match !call_froms_stack with
      | { table_for_calls } :: _ ->
        merge_call_froms table_for_calls call_site froms;
      | [] ->
        (* Empty call stack: this is the main entry point with no call site. *)
        assert (call_site = Cil_types.Kglobal);
    in
    let compute_from_behaviors bhv =
      let assigns = Ast_info.merge_assigns bhv in
      let froms =
        From_compute.compute_using_prototype_for_state
          initial_state current_function assigns
      in
      register_from froms
    in
    match value_res with
    | `Def (Eva.Cvalue_callbacks.{before_stmts}, memexec_counter) ->
      let froms =
        if Eva.Analysis.save_results cur_kf
        then compute_call_from_value_states cur_kf (Lazy.force before_stmts)
        else Function_Froms.top
      in
      let pre_state = match !call_froms_stack with
        | [] -> assert false
        | { value_initial_state } :: _ -> value_initial_state
      in
      if From_parameters.VerifyAssigns.get () then
        Eva.Logic_inout.verify_assigns cur_kf ~pre:pre_state froms;
      MemExec.replace memexec_counter froms;
      end_record callstack froms

    | `Reuse counter ->
      end_record callstack (MemExec.find counter)

    | `Builtin (_states, Some (result,_)) ->
      register_from result
    | `Builtin (_states, None) ->
      let behaviors =
        Eva.Logic_inout.valid_behaviors current_function initial_state
      in
      compute_from_behaviors behaviors
    | `Spec _states ->
      let spec = Annotations.funspec current_function in
      compute_from_behaviors spec.Cil_types.spec_behavior
  end


(* Register our callbacks inside the value analysis *)
let () =
  Eva.Cvalue_callbacks.register_call_hook call_for_individual_froms;
  Eva.Cvalue_callbacks.register_call_results_hook record_for_individual_froms

let iter = Tbl.iter
let find = Tbl.find

let compute_all_calldeps () =
  if not (Tbl.is_computed ()) then begin
    if Eva.Analysis.is_computed () then
      Project.clear
        ~selection:(State_selection.with_dependencies Eva.Analysis.self)
        ();
    Eva.Analysis.compute ()
  end

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
