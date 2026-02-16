(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Mt_thread

(* Mthread registers once and for all a few callbacks inside the value
   analysis. Depending on whether the plugin is active and the mthread analysis
   has not already been computed, the callbacks are set to functions that
   do nothing, or to real functions
*)

let no_hook = fun _ _ _ _ -> ()
let ref_hook_call_function = ref no_hook
let ref_hook_end_function = ref no_hook

let () = Cvalue_callbacks.register_call_hook
    (fun args -> !ref_hook_call_function args)

let () = Cvalue_callbacks.register_call_results_hook
    (fun args -> !ref_hook_end_function args)

(* Conversion from the simplified type of an mthread function into one suitable
   as a hook *)
let wrap_builtin analysis builtin = fun state args ->
  let state, res =
    try builtin analysis state args
    with Mt_analysis_hooks.Hook_failure res ->
      state, Some (Mt_memory.int_to_value res)
  in
  Builtins.Full
    { c_values = [res, state];
      c_clobbered = Base.SetLattice.bottom;
      c_assigns = None;
    }

let register_hooks analysis =
  ref_hook_call_function :=
    Mt_analysis_hooks.catch_functions_calls analysis;
  ref_hook_end_function :=
    Mt_analysis_hooks.catch_functions_record analysis;
  let register (name, builtin) =
    wrap_builtin analysis builtin
    |> Builtins.register_builtin name NoCacheCallers
  in
  List.iter register Mt_analysis_hooks.mthread_builtins

let unregister_hooks () =
  ref_hook_call_function := no_hook;
  ref_hook_end_function := no_hook;
  let unregister (name, _builtin) =
    Builtins.unregister_builtin name
  in
  List.iter unregister Mt_analysis_hooks.mthread_builtins


let checks () =
  Mt_lib.check_mthread_library ();

  if not (Mt_options.ConcatDotFilesTo.is_empty ()) &&
     not (Mt_options.ExtractModels.mem "html") then
    Mt_self.error "Option %S needs option \"%s html\" to work."
      Mt_options.ConcatDotFilesTo.option_name
      Mt_options.ExtractModels.option_name

let pre_analysis () =
  checks ();

  Mt_self.feedback "******* Starting mthread";

  (* We create the record containing the state of the analysis (which must
     remain unique, as it is used to define the callback for the value
     analysis.)

     For the current thread field, we use a dummy main thread, that will get
     overwritten once the real one is determined *)
  let f_main = fst @@ Globals.entry_point () in
  let dummy_main_thread =
    Mt_analysis_hooks.main_thread f_main Cvalue.Model.empty_map in
  let analysis = {
    all_threads = Thread.Hashtbl.create 17;
    all_mutexes = Mutex.Set.empty;
    all_queues = Mqueue.Set.empty;
    iteration = 0;
    curr_thread = dummy_main_thread;
    main_thread = dummy_main_thread;
    curr_events_stack = [];
    memexec_cache = Datatype.Int.Hashtbl.create 16;
    curr_stack = Callstack.init ~thread:(Thread.(id main)) ~entry_point:f_main;
    concurrent_accesses = Locations.Zone.bottom;
    precise_concurrent_accesses = Locations.Zone.bottom;
    concurrent_accesses_by_nodes = [];
  } in

  analysis

let post_analysis analysis =
  (* In the cfgs, mark whether the accesses are concurrent or not,
      and remove superfluous node *)
  Mt_analysis_fixpoint.mark_shared_nodes_kind analysis;

  (* Printing results to files *)
  Mt_options.ExtractModels.iter
    (fun s ->
       Mt_self.feedback "******* Outputting model for %s" s;
       (match s with
        | "html" -> Mt_outputs.Html.output_threads analysis;
        | _ -> Mt_self.error "Unknown model %s specified" s;
       );
       Mt_self.feedback "******* %s output done."
         (String.capitalize_ascii s);
    );

  Mt_summary.compute analysis

(* Perform an entire mthread execution on the current project *)
let mthread_run () =
  Mt_self.warning
    "Mthread is an experimental plugin and is still in development.";

  let analysis = pre_analysis () in

  (* We register our callback function *)
  register_hooks analysis;
  Fun.protect ~finally:unregister_hooks @@ fun () ->

  (* We analyse the main thread *)
  let module Engine = (val Engine.current ()) in
  Engine.Interferences.reset ();
  Thread.reset_state ();
  Mutex.reset_state ();
  Mqueue.reset_state ();
  Mt_summary.clear ();

  (* Let Eva know about interrupt handlers. *)
  Thread.register_interrupt_handlers (Mt_options.InterruptHandlers.get ());

  Mt_self.feedback "*** Computing value analysis for main thread";
  Analysis.mthread_pre_analysis ();
  Analysis.compute_thread Thread.main;
  Mt_self.feedback "*** First value analysis for main thread done." ;

  Mt_analysis_fixpoint.post_thread_analysis analysis;

  (* We perform the analysis iterations *)
  Mt_analysis_fixpoint.reach_fixpoint analysis;
  Analysis.mthread_post_analysis ();
  post_analysis analysis


let compute_mthread_once, _self =
  State_builder.apply_once "mthread_compute"
    [ Ast.self (*; Kernel.MainFunction.self *) ]
    (fun () -> mthread_run ())

let () =
  (* Automatically add Mthread shared directory to the include path and add the
     threads lib to the parsed sources if either -mt-threads-lib or -mthread
     is used.
     We do a best effort to add the stubbed files to the list of our files.
     This should work even if a plugin requests the computation of
     the AST before we have started running *)
  Cmdline.run_after_setting_files
    (fun _l ->
       if Mt_options.ThreadsLib.is_set () || Mt_options.Enabled.get () then
         Mt_lib.load_threads_library (Mt_options.ThreadsLib.get ()))

let () =
  (* Check that the threads lib stays consistent if the AST has already been
     computed with a specific variant. *)
  Mt_options.ThreadsLib.add_set_hook
    (fun old_value new_value ->
       if old_value <> new_value && Ast.is_computed () then
         Mt_self.warning
           "ignoring option %s specified after parsing"
           Mt_options.ThreadsLib.option_name)

let main () =
  if Mt_options.Enabled.get () then (
    compute_mthread_once ()
  )
let () = Boot.Main.extend main
