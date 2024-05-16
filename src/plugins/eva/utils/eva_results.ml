(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(* {2 Termination.} *)

let partition_terminating_instr stmt =
  match Cvalue_results.get_stmt_state_by_callstack ~after:true stmt with
  | `Bottom | `Top -> ([], [])
  | `Value h ->
    let terminating = ref [] in
    let non_terminating = ref [] in
    let add x xs = xs := x :: !xs in
    Callstack.Hashtbl.iter (fun cs state ->
        if Cvalue.Model.is_reachable state
        then add cs terminating
        else add cs non_terminating) h;
    (!terminating, !non_terminating)

let is_non_terminating_instr stmt =
  match partition_terminating_instr stmt with
  | [], _ -> true
  | _, _ -> false

(* {2 Global state.} *)

(* Option_ref that calls [Parameters.change_correctness] when its state
   is modified. *)
module Correctness_option_ref (Data: Datatype.S) (Info: State_builder.Info)
= struct
  include State_builder.Option_ref (Data) (Info)

  let set x =
    if not (Option.equal Data.equal (Some x) (get_option ())) then
      (Parameters.change_correctness (); set x)

  let clear () =
    if get_option () <> None then
      (Parameters.change_correctness (); clear ())
end

(* Values of the arguments of the main function of the analysis. *)
module ListArgs = Datatype.List (Cvalue.V)
module MainArgs =
  Correctness_option_ref
    (ListArgs)
    (struct
      let name = "Eva.Eva_results.MainArgs"
      let dependencies =
        [ Ast.self; Kernel.LibEntry.self; Kernel.MainFunction.self]
    end)
let () = Ast.add_monotonic_state MainArgs.self
let () = State_builder.Proxy.extend [MainArgs.self] Self.proxy

let get_main_args = MainArgs.get_option
let set_main_args = MainArgs.set
let use_default_main_args = MainArgs.clear

(* Initial cvalue state of the analysis. *)
module VGlobals =
  Correctness_option_ref
    (Cvalue.Model)
    (struct
      let name = "Eva.Eva_results.VGlobals"
      let dependencies = [Ast.self]
    end)
let () = State_builder.Proxy.extend [VGlobals.self] Self.proxy

let get_initial_state = VGlobals.get_option
let set_initial_state = VGlobals.set
let use_default_initial_state = VGlobals.clear

(* {2 Saving and restoring state} *)

type stmt_by_callstack = Cvalue.Model.t Callstack.Hashtbl.t

module AlarmsStmt =
  Datatype.Pair_with_collections (Alarms) (Stmt)
    (struct let module_name = "Value.Eva_results.AlarmStmt" end)

type results = {
  main: Kernel_function.t option (** None means multiple functions *);
  before_states: stmt_by_callstack Stmt.Hashtbl.t;
  after_states: stmt_by_callstack Stmt.Hashtbl.t;
  kf_initial_states: stmt_by_callstack Kernel_function.Hashtbl.t;
  kf_callers: Function_calls.t;
  initial_state: Cvalue.Model.t Lattice_bounds.or_bottom;
  initial_args: Cvalue.V.t list option;
  alarms: Property_status.emitted_status AlarmsStmt.Hashtbl.t;
  statuses: Property_status.emitted_status Property.Hashtbl.t
(** alarms are _not_ present here *);
  (* conditions then/else *)
}

let get_results () =
  let vue = Emitter.get Eva_utils.emitter in
  let main = Some (fst (Globals.entry_point ())) in
  let module CS = Callstack in
  let before_states = Stmt.Hashtbl.create 128 in
  let after_states = Stmt.Hashtbl.create 128 in
  let kf_initial_states = Kernel_function.Hashtbl.create 128 in
  let copy_states stmt =
    let copy h ~after stmt =
      match Cvalue_results.get_stmt_state_by_callstack ~after stmt with
      | `Top | `Bottom -> ()
      | `Value states -> Stmt.Hashtbl.add h stmt (CS.Hashtbl.copy states)
    in
    copy before_states ~after:false stmt;
    copy after_states ~after:true stmt;
  in
  let copy_kf kf =
    match Cvalue_results.get_initial_state_by_callstack kf with
    | `Top | `Bottom -> ()
    | `Value hstack ->
      Kernel_function.Hashtbl.add kf_initial_states kf (CS.Hashtbl.copy hstack);
      try
        let fundec = Kernel_function.get_definition kf in
        List.iter copy_states fundec.sallstmts
      with Kernel_function.No_Definition -> ()
  in
  Globals.Functions.iter copy_kf;
  let kf_callers = Function_calls.get_results () in
  let initial_state = Cvalue_results.get_global_state () in
  let initial_args = get_main_args () in
  let aux_statuses f_status ip =
    let aux_any_status e status =
      if Emitter.Usable_emitter.equal vue e.Property_status.emitter then
        f_status status
    in
    Property_status.iter_on_statuses aux_any_status ip
  in
  let alarms = AlarmsStmt.Hashtbl.create 128 in
  let aux_alarms _emitter kf stmt ~rank:_ alarm ca =
    let ip = Property.ip_of_code_annot_single kf stmt ca in
    let f_status st = AlarmsStmt.Hashtbl.add alarms (alarm, stmt) st in
    aux_statuses f_status ip
  in
  Alarms.iter aux_alarms;
  let statuses = Property.Hashtbl.create 128 in
  let aux_ip (ip: Property.t) =
    let add () =
      aux_statuses (fun st -> Property.Hashtbl.add statuses ip st) ip
    in
    match ip with
    | Property.IPCodeAnnot {Property.ica_ca} -> begin
        match Alarms.find ica_ca with
        | None -> (* real property *) add ()
        | Some _ -> (* alarm; do not save it here *) ()
      end
    | Property.IPReachable _ ->
      () (* TODO: save them properly, and restore them *)
    | _ -> add ()
  in
  Property_status.iter aux_ip;
  { before_states; after_states; kf_initial_states; kf_callers;
    initial_state; initial_args; alarms; statuses; main }

let set_results results =
  let selection = State_selection.with_dependencies Self.state in
  Project.clear ~selection ();
  (* Those two functions may clear Self.state. Start by them *)
  (* Initial state *)
  Cvalue_results.register_global_state true results.initial_state;
  (* Initial args *)
  begin match results.initial_args with
    | None -> use_default_main_args ()
    | Some l -> set_main_args l
  end;
  (* Pre- and post-states *)
  let register_states register (tbl: stmt_by_callstack Stmt.Hashtbl.t) =
    let copy stmt (h:stmt_by_callstack) =
      let aux_callstack callstack state =
        register callstack stmt state;
      in
      Callstack.Hashtbl.iter aux_callstack h
    in
    Stmt.Hashtbl.iter copy tbl
  in
  register_states Cvalue_results.register_state_before_stmt results.before_states;
  register_states Cvalue_results.register_state_after_stmt results.after_states;
  (* Kf initial state *)
  let aux_initial_state kf h =
    let aux_callstack callstack state =
      Cvalue_results.register_initial_state callstack kf state
    in
    Callstack.Hashtbl.iter aux_callstack h
  in
  Kernel_function.Hashtbl.iter aux_initial_state results.kf_initial_states;
  Function_calls.set_results results.kf_callers;
  (* Alarms *)
  let aux_alarms (alarm, stmt) st =
    let ki = Cil_types.Kstmt stmt in
    ignore (Alarms.register Eva_utils.emitter ki ~status:st alarm)
  in
  AlarmsStmt.Hashtbl.iter aux_alarms results.alarms;
  (* Statuses *)
  let aux_statuses ip st =
    Property_status.emit Eva_utils.emitter ~hyps:[] ip st
  in
  Property.Hashtbl.iter aux_statuses results.statuses;
  let b = Parameters.ResultsAll.get () in
  Cvalue_domain.State.Store.register_global_state b
    (`Value Cvalue_domain.State.top);
  Self.ComputationState.set Computed;
  Cvalue_results.mark_as_computed ();
;;

module HExt (H: Hashtbl.S) =
struct

  let map ?(fkey=fun k _v -> k) ?(fvalue = fun _k v -> v) h =
    let h' = H.create (H.length h) in
    let aux cs v = H.add h' (fkey cs v) (fvalue cs v) in
    H.iter aux h;
    h'

  let merge merge h1 h2 =
    let h = H.create (H.length h1 + H.length h2) in
    let aux1 key v =
      let v' =
        try merge key v (H.find h2 key)
        with Not_found -> v
      in
      H.add h key v'
    in
    let aux2 key v =
      if not (H.mem h1 key) then H.add h key v
    in
    H.iter aux1 h1;
    H.iter aux2 h2;
    h

  include H

end

module CallstackH = HExt(Callstack.Hashtbl)
module StmtH = HExt(Stmt.Hashtbl)
module KfH = HExt(Kernel_function.Hashtbl)
module PropertyH = HExt(Property.Hashtbl)
module AlarmsStmtH = HExt(AlarmsStmt.Hashtbl)


let change_callstacks f results =
  let change_callstack h =
    let fkey cs _ = f cs in
    CallstackH.map ~fkey h
  in
  let fvalue _key hcs = change_callstack hcs in
  let change_states h = StmtH.map ~fvalue h in
  let change_kf h = KfH.map ~fvalue h in
  { results with
    before_states = change_states results.before_states;
    after_states = change_states results.after_states;
    kf_initial_states = change_kf results.kf_initial_states
  }

let merge r1 r2 =
  let merge_cs _ = CallstackH.merge (fun _ -> Cvalue.Model.join) in
  (* Keep the "most informative" status. This is not what we do usually,
     because here False + Unknown = False, instead of Unknown *)
  let merge_statuses _ s1 s2 =
    let open Property_status in
    match s1, s2 with
    | False_and_reachable, _ | _, False_and_reachable -> False_and_reachable
    | False_if_reachable, _ | _, False_if_reachable -> False_if_reachable
    | Dont_know, _ | _, Dont_know -> Dont_know
    | True, True -> True
  in
  let merge_s_cs = StmtH.merge merge_cs in
  let main = match r1.main, r2.main with
    | None, _ | _, None -> None
    | Some kf1, Some kf2 ->
      if Kernel_function.equal kf1 kf2 then Some kf1 else None
  in
  let before_states = merge_s_cs r1.before_states r2.before_states in
  let after_states = merge_s_cs r1.after_states r2.after_states in
  let kf_initial_states =
    KfH.merge merge_cs r1.kf_initial_states r2.kf_initial_states
  in
  let kf_callers = Function_calls.merge_results r1.kf_callers r2.kf_callers in
  let alarms = AlarmsStmtH.merge merge_statuses r1.alarms r2.alarms in
  let statuses = PropertyH.merge merge_statuses r1.statuses r2.statuses in
  let initial_state =
    Lattice_bounds.Bottom.join Cvalue.Model.join r1.initial_state r2.initial_state
  in
  let initial_args =
    match main, r1.initial_args, r2.initial_args with
    | None, _, _ | _, None, _ | _, _, None -> None
    | Some _kf, Some args1, Some args2 ->
      (* same number of arguments : arity of [_kf] *)
      try Some (List.map2 Cvalue.V.join args1 args2)
      with Invalid_argument _ -> None (* should not occur *)
  in
  { main; before_states; after_states; kf_initial_states;
    initial_state; initial_args; alarms; statuses; kf_callers }

let eval_tlval_as_location ?result state term =
  let env = Eval_terms.env_post_f ~pre:state ~post:state ~result () in
  try Eval_terms.eval_tlval_as_location ~alarm_mode:Ignore env term
  with Eval_terms.LogicEvalError _ -> raise Logic_to_c.No_conversion

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
