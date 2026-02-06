(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* ----- Pre-analysis checks ------------------------------------------------ *)

(* Clear Eva's various caches. Some operations of Eva depend on parameters,
   such as -ilevel or -plevel, so clearing those caches ensures that those
   options have the expected effect.
   Caches are cleared at the beginning of each analysis, and whenever the
   Frama-C project library changes the local state of Eva. *)
let clear_caches () =
  Cvalue.V_Offsetmap.clear_caches ();
  Cvalue.Model.clear_caches ();
  Locations.Location_Bytes.clear_caches ();
  Locations.Zone.clear_caches ();
  Assigns.Memory.clear_caches ()

let () = State.add_hook_on_update Self.state clear_caches

let floats_ok () =
  let u = min_float /. 2. in
  let u = u /. 2. in
  assert (0. < u && u < min_float)

let need_assigns kf =
  let spec = Annotations.funspec kf in
  match Cil.find_default_behavior spec with
  | None -> true
  | Some bhv -> bhv.b_assigns = WritesAny

(* Check that we can parse the values specified for the options that require
   advanced parsing. Just make a query, as this will force the kernel to
   parse them. *)
let options_ok () =
  let check f = try ignore (f ()) with Not_found -> () in
  check Parameters.SplitReturnFunction.get;
  check Parameters.BuiltinsOverrides.get;
  check Parameters.SlevelFunction.get;
  check Parameters.EqualityCallFunction.get

let plugins_ok () =
  if not (Plugin.is_present "inout") then
    Self.warning
      "The inout plugin is missing: some features are disabled, \
       and the analysis may have degraded precision and performance."

(* Do something tasteless in case the user did not put a spec on functions
   for which he set [-eva-use-spec]:  generate an incorrect one ourselves *)
let generate_specs () =
  let aux kf =
    if need_assigns kf then begin
      Self.warning ~wkey:Self.wkey_missing_assigns
        "@[No assigns specified for function '%a' for which option %s is set. \
         Generating potentially incorrect assigns.@]"
        Kernel_function.pretty kf Parameters.UsePrototype.option_name;
      Populate_spec.populate_funspec ~do_body:true kf [`Assigns];
    end
  in
  Parameters.UsePrototype.iter aux

let pre_analysis () =
  Self.configure_verbosity ();
  Parameters.configure_precision ();
  Iterator.signal_reset ();
  floats_ok ();
  options_ok ();
  plugins_ok ();
  Split_return.pretty_strategies ();
  generate_specs ();
  Widen.precompute_widen_hints ();
  Builtins.prepare_builtins ();
  Statistics.reset_all ();
  clear_caches ();
  Eva_utils.DegenerationPoints.clear ();
  Cvalue_callbacks.apply_at_start_hooks ();
  Origin.clear ();
  if not (Kernel.AuditCheck.is_empty ()) then
    Eva_audit.check_configuration (Kernel.AuditCheck.get ())

(* ----- Post-analysis cleanup ---------------------------------------------- *)

let post_analysis () =
  (* Garbled mix must be dumped here -- at least before the call to
     mark_green_and_red -- because fresh ones are created when re-evaluating
     all the alarms, and we get an unpleasant "ghost effect". *)
  Self.warning ~wkey:Self.wkey_garbled_mix_summary "%t" Origin.pretty_history;
  (* Mark unreachable and RTE statuses. Only do this there, not when the
     analysis was aborted (hence, not in post_cleanup), because the
     propagation is incomplete. Also do not mark unreachable statutes if
     there is an alarm in the initializers (bottom initial state), as we
     would end up marking the alarm as dead. *)
  Eval_annots.mark_unreachable ();
  (* Try to refine the 'Unknown' statuses that have been emitted during
     this analysis. *)
  Eval_annots.mark_green_and_red ();
  Eva_dynamic.RteGen.mark_generated_rte ();
  Mem_exec.cleanup_results ();
  (* Remove redundant alarms *)
  if Parameters.RmAssert.get () then Eva_dynamic.Scope.rm_asserts ();
  (* The above functions may have changed the status of alarms. *)
  Summary.FunctionStats.recompute_all ();
  Red_statuses.report ()

(* ----- Signal handling ---------------------------------------------------- *)

(* Registers signal handlers for SIGUSR1 and SIGINT to cleanly abort the Eva
   analysis. Returns a function that restores previous signal behaviors after
   the analysis. *)
let register_signal_handler () =
  let warn () =
    Self.warning ~once:true "Stopping analysis at user request@."
  in
  let stop _ = warn (); Iterator.signal_abort ~kill:true in
  let interrupt _ = warn (); raise Sys.Break in
  let register_handler signal handler =
    match Sys.signal signal (Sys.Signal_handle handler) with
    | previous_behavior -> fun () -> Sys.set_signal signal previous_behavior
    | exception Invalid_argument _ -> fun () -> ()
    (* Ignore: SIGURSR1 is not available on Windows,
       and possibly on other platforms. *)
  in
  let restore_sigusr1 = register_handler Sys.sigusr1 stop in
  let restore_sigint = register_handler Sys.sigint interrupt in
  fun () -> restore_sigusr1 (); restore_sigint ()

(* ----- Analysis status ---------------------------------------------------- *)

type computation_state = Self.computation_state =
  | NotComputed | Computing | Computed | Aborted
let current_computation_state = Self.ComputationState.get
let register_computation_hook ?on f =
  let f' = match on with
    | None -> f
    | Some s -> fun s' -> if s = s' then f s
  in
  Self.ComputationState.add_hook_on_change f'

let is_computed = Self.is_computed
let self = Self.state
let emitter = Eva_utils.emitter

type results = Function_calls.results = Complete | Partial | NoResults
type status = Function_calls.analysis_status =
    Unreachable | SpecUsed | Builtin of string | Analyzed of results
let status kf =
  match Function_calls.analysis_status kf with
  | Analyzed Complete as status ->
    if is_computed () then status else Analyzed Partial
  | status -> status

let use_spec_instead_of_definition =
  Function_calls.use_spec_instead_of_definition ?recursion_depth:None

let save_results kf =
  try Function_calls.save_results (Kernel_function.get_definition kf)
  with Kernel_function.No_Definition -> false

(* ----- Running the analysis ------------------------------------------------ *)

type 'state engine = (module Engine_sig.S with type Dom.state = 'state)

let compute_from_init_state (type t) (engine: t engine) kf (init_state: t) =
  let module Engine = (val engine) in
  let restore_signals = register_signal_handler () in
  let compute () =
    let final_state = Engine.Compute.compute_main_call kf init_state in
    Engine.Dom.Store.mark_as_computed ();
    Self.(ComputationState.set Computed);
    post_analysis ();
    Engine.Dom.post_analysis final_state;
    Summary.print ();
    Statistics.export_as_csv ();
    restore_signals ()
  in
  let cleanup () =
    Engine.Dom.Store.mark_as_computed ();
    Self.(ComputationState.set Aborted)
  in
  Eva_utils.protect compute ~cleanup

let compute_from_entry_point (module Engine: Engine_sig.S) kf ~lib_entry =
  Self.feedback "Analyzing a%scomplete application starting at %a"
    (if lib_entry then "n in" else " ")
    Kernel_function.pretty kf;
  match Engine.Initialization.initial_state_with_formals ~lib_entry kf with
  | `Bottom ->
    Engine.Dom.Store.mark_as_computed ();
    Self.(ComputationState.set Aborted);
    Self.result "Eva not started because globals \
                 initialization is not computable.";
    Eval_annots.mark_invalid_initializers ()
  | `Value initial_state ->
    compute_from_init_state (module Engine) kf initial_state

(* Builds the analyzer if needed, and run the analysis. *)
let force_compute () =
  Ast.compute ();
  pre_analysis ();
  let kf, lib_entry = Globals.entry_point () in
  Engine.reset ();
  (* The new analyzer can be accessed through hooks *)
  Self.ComputationState.set Computing;
  let module Engine = (val Engine.current ()) in
  try compute_from_entry_point (module Engine) ~lib_entry kf
  with Self.Abort ->
    Self.(ComputationState.set Aborted);
    Self.error "The analysis has been aborted: results are incomplete."

let compute () =
  (* Nothing to recompute when Eva has already been computed. This boolean
      is automatically cleared when an option of Eva changes, because they
      are registered as dependencies on [Self.state] in {!Parameters}.*)
  if not (is_computed ()) then force_compute ()

let compute =
  let name = "Eva.Analysis.compute" in
  fst (State_builder.apply_once name [ Self.state ] compute)

let () = Parameters.ForceValues.set_output_dependencies [Self.state]

let main () = if Parameters.ForceValues.get () then compute ()
let () = Boot.Main.extend main

let abort () =
  if Self.ComputationState.get () = Computing
  then Iterator.signal_abort ~kill:false

(* Mthread entry point *)

let compute_thread thread kf initial_state args =
  (* We reset the concurrent Eva analysis (necessary because sometimes,
     only the hooks have changed, and this is not captured by the project
     infrastructure) *)
  Self.clear_results ();

  (* We set the parameters for the value analysis *)
  Eva_results.set_initial_state initial_state;
  Eva_results.set_main_args args;
  Thread.set_current thread;

  let module Engine = (val Engine.current ()) in
  try compute_from_entry_point (module Engine) ~lib_entry:false kf
  with Self.Abort ->
    Self.(ComputationState.set Aborted);
    Self.error "The analysis has been aborted: results are incomplete."
