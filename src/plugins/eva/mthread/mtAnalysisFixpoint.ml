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

open Cil_types
open MtTypes
open MtSharedVarsTypes
open MtMutexesTypes
open MtThread


(* If the thread sends more messages than before, we flag all the threads
   receiving messages on those queues as needed to be recomputed *)
let mark_new_messages_received analysis =
  let th = analysis.curr_thread in
  let is_send = function SendMsg _ -> true | _ -> false in
  let send_before = Trace.find_events is_send th.th_amap
  and send_after = Trace.find_events is_send (curr_events analysis) in
  (* YYY Not monotonic *)
  let diff = EventsSet.diff send_after send_before in
  if not (EventsSet.is_empty diff) then
    let queues = EventsSet.fold
        (fun evt queues -> match evt with
           | SendMsg (q, _) -> Mqueue.Set.add q queues
           | _ -> queues) diff Mqueue.Set.empty
    in
    MtOptions.debug "@[New message(s) sent@ on@ queue(s) %a@]"
      (Pretty_utils.pp_iter Mqueue.Set.iter Mqueue.pretty) queues;
    iter_threads analysis
      (fun th ->
         let should_recompute _stack = function
           | ReceiveMsg (q, _, _) -> Mqueue.Set.mem q queues
           | _ -> false
         in
         if Trace.exists th.th_amap should_recompute
         then (MtOptions.debug "Marking %a as having received new message(s)"
                 ThreadState.pretty th;
               ThreadState.recompute_because th NewMsgReceived)
      );
;;

let record_end_of_thread_analysis analysis interferences =
  let th = analysis.curr_thread in

  (* We save the state of the analysis *)
  MtOptions.feedback ~level:2
    "* Starting to save the state of the value analysis";

  let results = Eva_results.get_results () in
  th.th_value_results <- Some results;

  if MtOptions.ToDisk.get () then
    let th = ThreadState.label th |> MtLib.sanitize_filename in
    let name = Format.sprintf "%s%s_iteration_%d.sav"
        (MtOptions.ToDiskPrefix.get ())
        th analysis.iteration in
    Project.save (Filepath.Normalized.of_string name)
  else begin
    let p = lazy(
      let pname = Format.asprintf "%a, iteration %d"
          ThreadState.pretty th analysis.iteration
      in
      Project.create_by_copy ~last:false pname)
    in
    match MtOptions.KeepProjects.get () with
    | "all" ->
      th.th_projects <- Lazy.force p :: th.th_projects
    | "last" ->
      List.iter (fun project -> Project.remove ~project ()) th.th_projects;
      th.th_projects <- [Lazy.force p]
    | "none" -> ()
    | _ -> assert false (* checked by the command-line *)
  end;
  MtOptions.feedback ~level:2 "* state saved";

  mark_new_messages_received analysis;

  (* We compute the globals variables accessed by the thread *)
  MtOptions.feedback ~level:2 "* Computing shared variables";
  let state_accesser = MtMemory.Types.Global in
  let read_written = MtSharedVars.read_written_by_function
      (MtSharedVars.stmt_is_multithreaded analysis state_accesser)
      th.th_eva_thread state_accesser th.th_fun Kglobal in
  th.th_read_written <- read_written;
  MtOptions.result ~level:3 "@[<v 0>Globals accessed by thread:@ %a@]"
    AccessesByZone.pretty_map read_written;
  MtOptions.feedback ~level:2 "* shared variables computed";

  (* We compute interferences *)
  MtInterferences.add_last_analysis analysis interferences;

  (* We update the multithread events of the thread for its next iteration *)
  th.th_amap <- curr_events analysis;

  (* Compute the concurrent graph of this thread *)
  MtOptions.feedback ~level:2 "* Computing cfg";
  th.th_cfg <- MtCfg.make_cfg th;
  th.th_read_written_cfg <- MtCfg.cfg_accesses th.th_eva_thread th.th_cfg;
  MtOptions.feedback ~level:2 "* Cfg computed";
;;


(* We compute a value analysis for the given thread *)
let compute_thread analysis th =
  let time = Sys.time () in
  Project.clear
    ~selection:(State_selection.with_dependencies Messages.self) ();
  Messages.reset_once_flag ();

  MtOptions.feedback ~level:2 "* Computing value analysis for thread %a"
    Thread.pretty th.th_eva_thread;
  MtOptions.debug "@[<hov>Arguments@ %a@]"
    (Pretty_utils.pp_list Cvalue.V.pretty) th.th_params;
  MtOptions.debug ~level:2 "Initial state %a"
    Cvalue.Model.pretty th.th_init_state;

  (* We set the values that depend on the thread analysed *)
  analysis.curr_thread <- th;
  analysis.curr_events_stack <- [];
  Datatype.Int.Hashtbl.clear analysis.memexec_cache;

  (* We reset the concurrent value analysis (necessary because sometimes,
     only the hooks have changed, and this is not captured by the project
     infrastructure) *)
  MtLib.clear_value_results ();

  (* We set the parameters for the value analysis *)
  Globals.set_entry_point (Kernel_function.get_name th.th_fun) false;
  Eva_results.set_initial_state th.th_init_state;
  Eva_results.set_main_args th.th_params;
  Eva__Private.Thread.set_current th.th_eva_thread;

  Analysis.compute ();

  if MtOptions.ShowTime.get () then
    MtOptions.feedback ~level:2
      "* Value analysis computed for thread %a, %f sec"
      ThreadState.pretty th (Sys.time () -. time);
;;

let recompute_shared_vars_changed analysis before =
  iter_threads analysis
    (fun th ->
       try AccessesByZone.fold
             (fun z _ () ->
                if not (Locations.Zone.is_included z before) then raise Exit)
             th.th_read_written ()
       with Exit -> ThreadState.recompute_because th PotentialSharedVarsChanged
    )
;;

(** Recompute all the threads that are not [th], and that read a value
    that has changed between [before] and [now] *)
let recompute_shared_vars_values_changed analysis th before now =
  let changed_zone b offsm z =
    (* b is present in [now] but not in [before], or has changed: add the
       entire base to the changed_zone *)
    let default () =
      let zb = Locations.Zone.inject b Int_Intervals.top in
      Locations.Zone.join z zb
    in
    try
      match Cvalue.Model.find_base b before with
      | `Top | `Bottom -> assert false
      | `Value offsm' ->
        if Cvalue.V_Offsetmap.equal offsm offsm' then z
        else default ()
    with Not_found -> default ()
  in
  match now with
  | Cvalue.Model.Top | Cvalue.Model.Bottom -> assert false
  | Cvalue.Model.Map now ->
    (* Over-approximation of the zones changed from [before] to [now] *)
    let z_changed =
      Cvalue.Model.fold changed_zone now Locations.Zone.bottom
    in
    iter_threads analysis
      (fun th' ->
         if not (ThreadState.equal th' th) then
           try
             AccessesByZone.fold
               (fun z accesses () ->
                  if Locations.Zone.intersects z_changed z &&
                     (* YYY: recompute also threads that only write the variable?*)
                     (SetStmtIdAccess.exists (fun (op, _,_) -> op = Read) accesses)
                  then (
                    ThreadState.recompute_because th' SharedVarsValuesChanged;
                    raise Exit (* Speed up things, th' will be recomputed *) )
               ) th'.th_read_written ()
           with Exit -> ()
      )
;;


let compute_shared_vars analysis =
  let _imprecise =
    MtOptions.feedback "***** Computing shared variables";
    let (ww_accesses, rw_accesses), _ =
      MtSharedVars.Global.concurrent_accesses_all_threads
        (threads analysis) in
    let accesses = ww_accesses @ rw_accesses in
    MtOptions.debug ~level:2 "Global concurrent var accesses:@.%a"
      (MtSharedVars.Global.pretty_concurrent_accesses ()) accesses;
    let all_zones = MtSharedVars.Global.all_zones_accessed accesses in
    MtOptions.result ~level:3 "@[<hov 2>Imprecise locations to watch: %a@]"
      Locations.Zone.pretty all_zones;

    (* Detect changes *)
    if not (Locations.Zone.equal all_zones analysis.concurrent_accesses)
    then (
      let before = analysis.concurrent_accesses in
      MtOptions.feedback ~level:2 "@[<v>Concurrent imprecise accesses have \
                                   changed: before@ @[<hov 2>  %a@]@ vs.@ @[<hov 2>  %a@]"
        Locations.Zone.pretty before Locations.Zone.pretty all_zones;
      let after = Locations.Zone.join before all_zones in
      analysis.concurrent_accesses <- after;
      recompute_shared_vars_changed analysis before;
    )
  in

  (* Precise computation. Very similar to the above code, we just compute,
     store and print things differently *)
  let precise =
    let (ww_accesses, rw_accesses), zmap =
      MtSharedVars.Precise.concurrent_accesses_all_threads
        (threads analysis) in
    if MtOptions.DumpSharedVarsValues.get () > 0 then
      MtSharedVars.Precise.display_shared_vars_value zmap;
    let written = MtSharedVars.Precise.enumerate_written_vars_value zmap in
    let all_accesses = ww_accesses @ rw_accesses in
    let header fmt = Format.fprintf fmt "Possible read/write data races:" in
    MtOptions.printf ~level:1 ~header "  @[<v 0>%a@]"
      MtMutexes.pretty_with_mutexes rw_accesses;
    if MtOptions.WriteWriteRaces.get () then begin
      let header fmt = Format.fprintf fmt "Possible write/write data races:" in
      MtOptions.printf ~level:1 ~header "  @[<v 0>%a@]"
        MtMutexes.pretty_with_mutexes ww_accesses;
    end;
    let all_zones = MtSharedVars.Precise.all_zones_accessed (ww_accesses @ rw_accesses) in
    MtOptions.result ~level:2 "@[<hov 2>Shared memory:@ %a@]"
      Locations.Zone.pretty all_zones;

    (* Detect changes *)
    if not (Locations.Zone.equal all_zones analysis.precise_concurrent_accesses)
    then (
      let before = analysis.precise_concurrent_accesses in
      MtOptions.feedback ~level:2
        "@[<v>Concurrent precise var accesses have changed: before@ \
         @[<hov 2>  %a@]@ \
         vs.@ \
         @[<hov 2>  %a@]@]"
        Locations.Zone.pretty before Locations.Zone.pretty all_zones;
      (* let after = Locations.Zone.join before all_zones in *)
      analysis.precise_concurrent_accesses <- all_zones;
      (* No need to recompute for the moment, this field is not used by
         the analysis *)
    );
    all_accesses, written
  in
  precise
;;

(* Update the th_values_written field of all the threads, using the
   list of concurrent accesses that is returned by the shared var analysis.

   This function must be called once the [th_read_written] fields have been
   updated to ensure correct convergence *)
let store_written_value analysis lw =
  let aux th =
    let l = List.filter (fun (id, _, _) -> Thread.equal id th.th_eva_thread) lw in
    let old_written = th.th_values_written in
    let written = MtSharedVars.Precise.join_shared_values l in
    (* XXX: temporary *)
    let priority, hint =
      Widen_type.hints_from_keys Cil.dummyStmt (Widen_type.default ())
    in
    let written = Cvalue.Model.widen ~priority ~hint old_written written in
    let changed = not (Cvalue.Model.equal written old_written) in
    if changed then
      recompute_shared_vars_values_changed analysis th old_written written;
    if MtOptions.DumpSharedVarsValues.get () > 0 &&
       not (Cvalue.Model.equal Cvalue.Model.empty_map written)
    then
      MtOptions.result "@[Write summary for %a%t:@ %a@]"
        ThreadState.pretty th
        (fun fmt -> if changed then Format.fprintf fmt " (updated)")
        Cvalue.Model.pretty written;
    th.th_values_written <- written
  in
  iter_threads analysis aux


(* Function that does one pass of value analysis on all the threads
   that are marked as needed to be recomputed. Returns the values
   written by each thread recomputed*)
let one_iteration analysis interferences =
  iter_threads analysis
    (fun th ->
       if not (SetRecomputeReason.is_empty th.th_to_recompute) then (
         if MtThread.should_compute_thread th then
           if Cvalue.Model.is_reachable th.th_init_state then (
             MtOptions.feedback
               "@[<hov 2>*** Computing thread %a,@ iteration %d@ (%a)@]"
               ThreadState.pretty th analysis.iteration
               (Pretty_utils.pp_iter ~sep:",@ "
                  SetRecomputeReason.iter RecomputeReason.pretty)
               th.th_to_recompute;

             compute_thread analysis th;

             (* We save all our results *)
             record_end_of_thread_analysis analysis interferences;
             MtOptions.feedback "*** Thread %a computed" ThreadState.pretty th;
           ) else (
             MtOptions.feedback "@[<hov 2>*** Thread %a has been@ created but@ \
                                 not started. Skipping.@]"  ThreadState.pretty th
           )
         else (
           MtOptions.feedback "*** Skipping thread %a as requested"
             ThreadState.pretty th;
         );
         th.th_to_recompute <- SetRecomputeReason.empty;
       ) else
         MtOptions.debug "No need to recompute thread %a" ThreadState.pretty th
    );
  MtOptions.feedback "***** Threads computed for iteration %d."
    analysis.iteration;

  (* We update the locked mutexes and started threads information of the
     cfg. This must obviously be done before shared variables are computed,
     but it supposes the thread creation structure is completely known.
     Hence, it is safer to do this at the end of a full iteration, instead
     of at the end of a thread *)
  MtOptions.feedback ~level:2 "* Computing live threads and locked mutexes";
  iter_threads analysis (MtCfg.update_cfg_contexts analysis);
  MtOptions.feedback ~level:2 "* threads and mutexes computed";

  let precise_accesses, written = compute_shared_vars analysis in
  analysis.concurrent_accesses_by_nodes <- precise_accesses;
  store_written_value analysis written;

  let mutexes = MtMutexes.mutexes_protecting_zones' precise_accesses in
  MtOptions.result "@[<v 0>Mutexes for concurrent accesses:@ %a@]"
    MutexesByZone.pretty mutexes;
  if MtOptions.CheckProtections.get () then begin
    let protections = MtMutexes.check_protection analysis precise_accesses in
    MtOptions.result "Detailed shared zones protections@.%a"
      MtMutexes.pretty_protections protections;
    let ill_protected = MtMutexes.ill_protected precise_accesses protections in
    let need_sync = MtMutexes.need_sync ill_protected in
    if need_sync <> [] then begin
      let pp fmt (stmt, z) =
        Format.fprintf fmt "@[%a (for %a)@]"
          Cil_datatype.Location.pretty (Cil_datatype.Stmt.loc stmt)
          Locations.Zone.pretty z
      in
      MtOptions.result "Statements needing manual synchronisation@.%a"
        (Pretty_utils.pp_list ~pre:"@[<v>" ~sep:"@ " ~suf:"@]" pp) need_sync
    end;
  end;
  MtOptions.feedback "***** Shared variables computed";

  fold_threads analysis false
    (fun th v -> v || not (SetRecomputeReason.is_empty th.th_to_recompute))
;;


(* Remove "white" nodes in the cfg, ie accesses to variables that
   are not concurrent at all. Done at the very end of the analysis
   because
   - those nodes are needed before to reach the fixpoint
   - the marking of nodes by colors is not used by the analysis
     YYY: this can endanger restarting the analysis from the last point
     (the fixpoint may not be reached immediately, or we might reach a wrong
     one concerning shared variables). This should probably be done in
     a copy of the cfgs, but this means rewriting a fair amount of other
     analysis structures too *)
let mark_shared_nodes_kind analysis =
  let precise_accesses = analysis.concurrent_accesses_by_nodes in
  let shared_vars = MtSharedVars.Precise.all_zones_accessed precise_accesses in
  (* Update the informations in the cfgs *)
  iter_threads analysis
    (fun th -> MtSharedVars.Precise.remove_non_concur_zones_from_cfg
        shared_vars th.th_cfg
    );
  MtSharedVars.Precise.mark_concur_access_in_cfg precise_accesses;
  if (not (MtOptions.KeepWhiteNodes.get ()) ||
      not (MtOptions.KeepGreenNodes.get ()))
  && not (MtOptions.FullCfg.get ())
  then
    iter_threads analysis
      (fun th ->
         let keep =
           match MtOptions.KeepWhiteNodes.get (),
                 MtOptions.KeepGreenNodes.get () with
           | false, false -> MtCfgTypes.ConcurrentAccess
           | false, true  -> MtCfgTypes.SharedVarNonConcurrentAccess
           | true,  true  -> MtCfgTypes.NotReallySharedVar
           | true,  false ->
             MtOptions.warning ~once:true
               "Incoherent@ combination@ of@ options@ %s@ \
                and@ %s.@ Only@ non-shared@ variables@ will@ be@ removed."
               MtOptions.KeepWhiteNodes.option_name
               MtOptions.KeepGreenNodes.option_name;
             MtCfgTypes.SharedVarNonConcurrentAccess
         in
         let cfg = MtCfg.remove_superfluous_nodes ~keep th.th_cfg in
         th.th_cfg <- cfg;
      );
;;


(* Auxiliary function iterating the analysis until the fixpoint is reached *)
let reach_fixpoint analysis interferences =
  MtOptions.feedback "******* Starting to iterate";
  let rec aux i =
    MtOptions.feedback "***** Iteration %d" i;
    analysis.iteration <- i;
    let continue = one_iteration analysis interferences in
    if continue && i < MtOptions.StopAfter.get () then aux (i+1)
    else (* Stop iteration *)
    if continue then
      MtOptions.feedback
        "@[<v 0>\
         @[<hov 2>******* Analysis stopped after@ \
         %d iterations.@ Remaining@ to@ do:@]@ \
         %a@]" i
        (fun fmt () -> iter_threads analysis
            (fun th -> if not (SetRecomputeReason.is_empty th.th_to_recompute) then
                Format.fprintf fmt "@[<hov 2>Thread %a:@ %a@]@ "
                  ThreadState.pretty_detailed th
                  (Pretty_utils.pp_iter ~sep:",@ " ~pre:"" ~suf:""
                     SetRecomputeReason.iter RecomputeReason.pretty)
                  th.th_to_recompute
            )
        ) ()
    else
      MtOptions.feedback "******* Analysis performed, %d iterations" i
  in
  aux 1
