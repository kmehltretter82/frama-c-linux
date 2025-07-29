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


let hook_builtins =
  lazy (
    (* a generic function that does nothing *)
    let nop st _args = st, None in

    (* We create a reference for each of our builtin functions *)
    let lref = List.map (fun e -> (ref nop, e)) Mt_analysis_hooks.mthread_builtins in

    (* We register one hook by function, that simply dereferences the
       corresponding reference (up to some interface conversion) *)
    List.iter (fun (r, (s, _)) ->
        (* Conversion from the simplified type of an mthread function
           into one suitable as a hook *)
        Builtins.register_builtin s NoCacheCallers
          (fun st args ->
             let st, res =
               try !r st args
               with Mt_analysis_hooks.Hook_failure res ->
                 st, Some (Mt_memory.int_to_value res)
             in
             Builtins.Full
               { c_values = [res, st];
                 c_clobbered = Base.SetLattice.bottom;
                 c_assigns = None;
               }
          )) lref;

    (* And finally, we return a function that sets all the references either
       to nop, or to the suitable hook function *)
    (function
      | None -> (* Disable the hook *)
        List.iter (fun (r, _) -> r := nop) lref;
        ref_hook_call_function := no_hook;
        ref_hook_end_function := no_hook;

      | Some analysis ->
        List.iter (fun (r, (_s, f)) -> r:= f analysis) lref;
        ref_hook_call_function :=
          Mt_analysis_hooks.catch_functions_calls analysis;
        ref_hook_end_function :=
          Mt_analysis_hooks.catch_functions_record analysis;
    )
  )

let ref_analysis = ref None
let analysis_hook = ref []

let register_analysis_hook hook =
  analysis_hook := hook :: !analysis_hook

let apply_analysis_hooks () =
  let apply analysis = List.iter (fun hook -> hook analysis) !analysis_hook in
  Option.iter apply !ref_analysis

(* Perform an entire mthread execution, based on the ast and options of the
   given project *)
let mthread_run project =
  Mt_self.warning
    "Mthread is an experimental plugin and is still in development.";

  if not (Mt_options.ConcatDotFilesTo.is_empty ()) &&
     not (Mt_options.ExtractModels.mem "html") then
    Mt_self.error "Option %S needs option \"%s html\" to work."
      Mt_options.ConcatDotFilesTo.option_name
      Mt_options.ExtractModels.option_name;

  let old_project = Project.current () in
  Project.set_current project;
  let hook_builtins = Lazy.force hook_builtins in

  Mt_self.feedback "******* Starting mthread";

  (* We force the computation of the AST before this stage, so that it does not
     get recomputed in some other projects later *)
  Ast.compute ();

  (* Make sure that Mthread won't restart in one of the other projects
     or once the fixpoint is reached. *)
  Mt_options.Enabled.set false;

  (* We create the record containing the state of the analysis (which must
     remain unique, as it is used to define the callback for the value
     analysis.)

     For the current thread field, we use a dummy main thread, that will get
     overwritten once the real one is determined *)
  let f_main =
    try fst (Globals.entry_point ())
    with Globals.No_such_entry_point s ->
      Mt_self.abort "%s Mthread cannot run" s
  in
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

  (* We register our callback function *)
  hook_builtins (Some analysis);

  ref_analysis := Some analysis;
  apply_analysis_hooks ();

  (* Cleanup function, called at the end or in case of failure or success. *)
  let cleanup () =
    apply_analysis_hooks ();
    hook_builtins None;
    Project.set_current old_project;
  in

  try
    (* We analyse the main thread *)
    let module Analyzer = (val Analysis.current_analyzer ()) in
    Analyzer.Interferences.reset ();
    Mt_lib.clear_value_results ();
    Thread.reset_state ();
    Mutex.reset_state ();
    Mqueue.reset_state ();

    (* Let Eva know about interrupt handlers. *)
    Thread.register_interrupt_handlers (Mt_options.InterruptHandlers.get ());

    Mt_self.feedback "*** Computing value analysis for main thread";
    Analysis.compute ();
    Mt_self.feedback "*** First value analysis for main thread done." ;

    (* The hooks of the value analysis have now found the real main thread *)
    let main_th = analysis.curr_thread in
    let results = Eva_results.get_results () in
    main_th.th_value_results <- Some results;

    Mt_analysis_fixpoint.record_end_of_thread_analysis analysis;

    (* We perform the analysis iterations *)
    Mt_analysis_fixpoint.reach_fixpoint analysis;

    (* In the cfgs, mark whether the accesses are concurrent or not,
       and remove superfluous node *)
    Mt_analysis_fixpoint.mark_shared_nodes_kind analysis;

    (* We display the combination of all analyses *)
    Mt_outputs.Eva_results.display analysis;

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

    cleanup ();

  with e -> cleanup (); raise e


let compute_mthread_once, _self =
  State_builder.apply_once "mthread_compute"
    [ Ast.self (*; Kernel.MainFunction.self *) ]
    (fun () -> mthread_run (Project.current ()))

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
