(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

open MtThread

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
    let lref = List.map (fun e -> (ref nop, e)) MtAnalysisHooks.mthread_builtins in

    (* We register one hook by function, that simply dereferences the
       corresponding reference (up to some interface conversion) *)
    List.iter (fun (r, (s, _)) ->
        (* Conversion from the simplified type of an mthread function
           into one suitable as a hook *)
        Builtins.register_builtin s NoCacheCallers
          (fun st args ->
             let st, res =
               try !r st args
               with MtAnalysisHooks.Hook_failure res ->
                 st, Some (MtMemory.int_to_value res)
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
          MtAnalysisHooks.catch_functions_calls analysis;
        ref_hook_end_function :=
          MtAnalysisHooks.catch_functions_record analysis;
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
  MtOptions.warning
    "Mthread is an experimental plugin and is still in development.";
  let old_project = Project.current () in
  Project.set_current project;
  let hook_builtins = Lazy.force hook_builtins in

  MtOptions.feedback "******* Starting mthread";

  (* We force the computation of the AST before this stage, so that it does not
     get recomputed in some other projects later *)
  Ast.compute ();

  (* Make sure that Mthread won't restart in one of the other projects
     or once the fixpoint is reached. *)
  MtOptions.Enabled.set false;

  (* We create the record containing the state of the analysis (which must
     remain unique, as it is used to define the callback for the value
     analysis.)

     For the current thread field, we use a dummy main thread, that will get
     overwritten once the real one is determined *)
  let f_main =
    try fst (Globals.entry_point ())
    with Globals.No_such_entry_point s ->
      MtOptions.abort "%s Mthread cannot run" s
  in
  let dummy_main_thread =
    MtAnalysisHooks.main_thread f_main Cvalue.Model.empty_map in
  let analysis = {
    all_threads = Thread.Hashtbl.create 17;
    all_mutexes = Mutex.Set.empty;
    all_queues = Mqueue.Set.empty;
    iteration = 0;
    curr_thread = dummy_main_thread;
    main_thread = dummy_main_thread;
    curr_events_stack = [];
    memexec_cache = Datatype.Int.Hashtbl.create 16;
    curr_stack = Callstack.init f_main;
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
    MtLib.clear_value_results ();
    Thread.reset_state ();
    Mutex.reset_state ();
    MtOptions.feedback "*** Computing value analysis for main thread";
    Analysis.compute ();
    MtOptions.feedback "*** First value analysis for main thread done." ;

    (* The hooks of the value analysis have now found the real main thread *)
    let main_th = analysis.curr_thread in
    let results = Eva_results.get_results () in
    main_th.th_value_results <- Some results;

    let interferences = MtInterferences.initial () in
    MtAnalysisFixpoint.record_end_of_thread_analysis analysis interferences;

    (* We perform the analysis iterations *)
    MtAnalysisFixpoint.reach_fixpoint analysis interferences;

    (* In the cfgs, mark whether the accesses are concurrent or not,
       and remove superfluous node *)
    MtAnalysisFixpoint.mark_shared_nodes_kind analysis;

    (* We display the combination of all analyses *)
    MtOutputs.Eva_results.display analysis;

    (* Printing results to files *)
    MtOptions.ExtractModels.iter
      (fun s ->
         MtOptions.feedback "******* Outputting model for %s" s;
         (match s with
          | "html" -> MtOutputs.Html.output_threads analysis;
          | _ -> MtOptions.error "Unknown model %s specified" s;
         );
         MtOptions.feedback "******* %s output done."
           (String.capitalize_ascii s);
      );

    cleanup ();

  with e -> cleanup (); raise e


let compute_mthread_once, _self =
  State_builder.apply_once "mthread_compute"
    [ Ast.self (*; Kernel.MainFunction.self *) ]
    (fun () -> mthread_run (Project.current ()))


(* We do a best effort to add [mthread.h] to the list of our files.
   This should work even if a plugin requests the computation of
   the AST before we have started running *)
let () = Cmdline.run_after_setting_files
    (fun _l ->
       if MtOptions.Enabled.get () then
         let f = File.from_filename (MtLib.mthread_h ()) in
         File.pre_register f;
    )

let main () =
  if MtOptions.Enabled.get () then (
    compute_mthread_once ()
  )
let () = Boot.Main.extend main
