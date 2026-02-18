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
  Signal.reset ();
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

exception Error

let compute_from_entry_point  (type t) (engine: t engine)
    ?(thread=Thread.main) ?cvalue_state ?arguments entry_point =
  let module Engine = (val engine) in
  let lib_entry = Kernel.LibEntry.get () in
  Self.feedback "Analyzing a%scomplete application starting at %a"
    (if lib_entry then "n in" else " ")
    Kernel_function.pretty entry_point;
  match Engine.Initialization.initial_state_with_formals
          ?cvalue_state ?arguments ~lib_entry entry_point with
  | `Bottom ->
    Eval_annots.mark_invalid_initializers ();
    Self.error "Eva not started because globals \
                initialization is not computable.";
    raise Error
  | `Value initial_state ->
    Engine.Compute.compute_main_call ~thread entry_point initial_state

(* Builds the analyzer if needed, and run the analysis. *)
let compute_from ?cvalue_state ?arguments entry_point =
  Self.clear_results ();
  Ast.compute ();
  pre_analysis ();
  (* The new analyzer can be accessed through hooks *)
  let module Engine = (val Engine.reset ()) in
  let compute () =
    compute_from_entry_point (module Engine)
      ?cvalue_state ?arguments entry_point
  in
  try
    Self.ComputationState.set Computing;
    let restore_signals = Signal.setup () in
    let final_state = Fun.protect ~finally:restore_signals compute in
    Self.(ComputationState.set Computed);
    post_analysis ();
    Engine.Dom.post_analysis final_state;
    Summary.print ();
    Statistics.export_as_csv ();
  with exn ->
    Self.(ComputationState.set Aborted);
    match exn with
    | Error | Self.Abort -> () (* do not re-raise  *)
    | exn -> raise exn

let compute () =
  (* Nothing to recompute when Eva has already been computed. This boolean
      is automatically cleared when an option of Eva changes, because they
      are registered as dependencies on [Self.state] in {!Parameters}.*)
  if not (is_computed ()) then
    let cvalue_state = Eva_results.get_initial_state ()
    and arguments = Eva_results.get_main_args ()
    and entry_point = fst @@ Globals.entry_point () in
    compute_from ?cvalue_state ?arguments entry_point

let compute =
  let name = "Eva.Analysis.compute" in
  fst (State_builder.apply_once name [ Self.state ] compute)

let () = Parameters.ForceValues.set_output_dependencies [Self.state]

let main () = if Parameters.ForceValues.get () then compute ()
let () = Boot.Main.extend main

let abort () =
  Signal.abort ()

(* Mthread entry point *)

let compute_thread ?cvalue_state thread =
  let Thread.{ entry_point; arguments } = Thread.properties thread in
  let arguments =
    if Thread.is_main thread
    then None (* use generated main arguments *)
    else Some (List.map snd arguments)
  in
  let module Engine = (val Engine.current ()) in
  try
    (* In multi thread analyses, Memexec cache must be invalidated *)
    Mem_exec.cleanup_results ();
    Self.ComputationState.set Computing;
    let final_state = compute_from_entry_point (module Engine)
        ~thread ?cvalue_state ?arguments entry_point in
    Self.ComputationState.set Computed;
    (* Display the final state of each thread main function *)
    Engine.Dom.post_analysis final_state
  with exn ->
    Self.(ComputationState.set Aborted);
    match exn with
    | Error | Self.Abort -> () (* do not re-raise *)
    | exn -> raise exn

let mthread_thread_analysis analysis th =
  let open Mt_thread in
  if SetRecomputeReason.is_empty th.th_to_recompute then
    Mt_self.debug "No need to recompute thread %a" ThreadState.pretty th
  else if not (Mt_thread.should_compute_thread th) then
    Mt_self.feedback "*** Skipping thread %a as requested"
      ThreadState.pretty th
  else if not (Cvalue.Model.is_reachable th.th_init_state) then
    Mt_self.feedback "@[<hov 2>*** Thread %a has been@ created but@ \
                      not started. Skipping.@]"  ThreadState.pretty th
  else begin
    Mt_self.feedback
      "@[<hov 2>*** Computing thread %a,@ iteration %d@ (%a)@]"
      ThreadState.pretty th analysis.iteration
      SetRecomputeReason.pretty th.th_to_recompute;

    Mt_analysis_fixpoint.pre_thread_analysis analysis th;

    let (), analysis_time = Eva_utils.measure_time
        (compute_thread ~cvalue_state:th.th_init_state) th.th_eva_thread in

    if Mt_options.ShowTime.get () then
      Mt_self.feedback ~level:2
        "* Value analysis computed for thread %a, %f sec"
        ThreadState.pretty th analysis_time;

    (* We save all our results *)
    Mt_analysis_fixpoint.post_thread_analysis analysis;

    Mt_self.feedback "*** Thread %a computed" ThreadState.pretty th;
  end;
  th.th_to_recompute <- SetRecomputeReason.empty

(* Auxiliary function iterating the analysis until the fixpoint is reached *)
let mthread_fixpoint analysis =
  let open Mt_thread in

  Mt_self.feedback "******* Starting to iterate";
  let limit = Mt_options.StopAfter.get () in
  analysis.iteration <- 0;
  while
    analysis.iteration < limit &&
    not (Mt_analysis_fixpoint.is_fixpoint_reached analysis)
  do
    analysis.iteration <- analysis.iteration + 1;
    Mt_self.feedback "***** Iteration %d" analysis.iteration;
    iter_threads analysis (mthread_thread_analysis analysis);
    Mt_self.feedback "***** Threads computed for iteration %d."
      analysis.iteration;
    Mt_analysis_fixpoint.post_iteration analysis
  done;

  if Mt_analysis_fixpoint.is_fixpoint_reached analysis then
    Mt_self.feedback "******* Analysis performed, %d iterations"
      analysis.iteration
  else
    Mt_self.feedback
      "@[<v>******* Analysis stopped after %d iterations.\
       @ Remaining to do: %a@]"
      analysis.iteration
      pretty_recompute_reasons analysis

(* Perform an entire mthread execution on the current project *)
let mthread_compute () =
  Mt_self.warning
    "Mthread is an experimental plugin and is still in development.";

  let analysis = Mt_main.pre_analysis () in

  (* We register our callback function *)
  Mt_main.register_hooks analysis;
  Fun.protect ~finally:Mt_main.unregister_hooks @@ fun () ->

  let module E = (val Engine.reset ()) in
  E.Interferences.reset ();
  Thread.reset_state ();
  Mutex.reset_state ();
  Mqueue.reset_state ();
  Mt_summary.clear ();

  (* Let Eva know about interrupt handlers. *)
  Thread.register_interrupt_handlers (Mt_options.InterruptHandlers.get ());

  (* We analyse the main thread *)
  Mt_self.feedback "*** Computing value analysis for main thread";
  Self.clear_results ();
  Ast.compute ();
  pre_analysis ();

  compute_thread Thread.main;
  Mt_self.feedback "*** First value analysis for main thread done." ;

  Mt_analysis_fixpoint.post_thread_analysis analysis;

  (* We perform the analysis iterations *)
  mthread_fixpoint analysis;
  post_analysis ();
  Summary.print ();
  Statistics.export_as_csv ();
  Mt_main.post_analysis analysis

let mthread_compute_once, _self =
  State_builder.apply_once "Eva.Analysis.mthread_compute"
    [ Ast.self (*; Kernel.MainFunction.self *) ]
    (fun () -> mthread_compute ())

let mthread_main () = if Mt_options.Enabled.get () then mthread_compute_once ()
let () = Boot.Main.extend mthread_main
