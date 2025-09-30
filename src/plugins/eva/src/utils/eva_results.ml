(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_datatype

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

type results = {
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
  let module CS = Callstack in
  let before_states = Stmt.Hashtbl.create 128 in
  let after_states = Stmt.Hashtbl.create 128 in
  let kf_initial_states = Kernel_function.Hashtbl.create 128 in
  let copy_states stmt =
    match Cvalue_results.stmt_callstacks stmt with
    | `Top -> ()
    | `Value callstacks ->
      let copy_callstack by_cs ~after stmt callstack =
        match Cvalue_results.get_stmt_state ~callstack ~after stmt with
        | `Bottom -> ()
        | `Value state -> CS.Hashtbl.replace by_cs callstack state
      in
      let copy h ~after stmt =
        let by_cs = CS.Hashtbl.create (Seq.length callstacks) in
        Seq.iter (copy_callstack by_cs ~after stmt) callstacks;
        Stmt.Hashtbl.replace h stmt by_cs
      in
      copy before_states ~after:false stmt;
      copy after_states ~after:true stmt;
  in
  let copy_kf kf =
    match Cvalue_results.kf_callstacks kf with
    | `Top -> ()
    | `Value callstacks ->
      let by_cs = CS.Hashtbl.create (Seq.length callstacks) in
      let copy_callstack callstack =
        match Cvalue_results.get_initial_state ~callstack kf with
        | `Bottom -> ()
        | `Value state -> CS.Hashtbl.replace by_cs callstack state
      in
      Seq.iter copy_callstack callstacks;
      Kernel_function.Hashtbl.replace kf_initial_states kf by_cs;
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
    initial_state; initial_args; alarms; statuses; }

let set_results results =
  let selection = State_selection.with_dependencies Self.state in
  Project.clear ~selection ();
  Parameters.change_correctness ();
  (* Those two functions may clear Self.state. Start by them *)
  (* Initial state *)
  Cvalue_results.set_global_state true results.initial_state;
  (* Initial args *)
  begin match results.initial_args with
    | None -> use_default_main_args ()
    | Some l -> set_main_args l
  end;
  (* Pre- and post-states *)
  let register_states ~after (tbl: stmt_by_callstack Stmt.Hashtbl.t) =
    let copy stmt (h:stmt_by_callstack) =
      let aux_callstack callstack state =
        Cvalue_results.set_stmt_state ~callstack ~after stmt state;
      in
      Callstack.Hashtbl.iter aux_callstack h
    in
    Stmt.Hashtbl.iter copy tbl
  in
  register_states ~after:false results.before_states;
  register_states ~after:true results.after_states;
  (* Kf initial state *)
  let aux_initial_state kf h =
    let aux_callstack callstack state =
      Cvalue_results.set_initial_state ~callstack kf state
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
  (* Sort alarms, as the order in which several alarms on a same statement are
     registered impacts the order in which they are displayed. *)
  let cmp (a1, s1) (a2, s2) =
    let n = Stmt.compare s1 s2 in
    if n <> 0 then n else Alarms.compare a1 a2
  in
  AlarmsStmt.Hashtbl.iter_sorted ~cmp aux_alarms results.alarms;
  (* Statuses *)
  let aux_statuses ip st =
    Property_status.emit Eva_utils.emitter ~hyps:[] ip st
  in
  Property.Hashtbl.iter aux_statuses results.statuses;
  let b = Parameters.ResultsAll.get () in
  Cvalue_domain.State.Store.set_global_state b
    (`Value Cvalue_domain.State.top);
  Self.ComputationState.set Computed
