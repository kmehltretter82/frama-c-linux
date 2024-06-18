(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

let dkey_main = Wp_parameters.register_category "main"
let dkey_raised = Wp_parameters.register_category "raised"
let dkey_script_removed =
  Wp_parameters.register_category "script:show-removed"
let dkey_script_updated =
  Wp_parameters.register_category "script:show-updated"
let dkey_script_incomplete =
  Wp_parameters.register_category "script:show-incomplete"

(* ------------------------------------------------------------------------ *)
(* --- Memory Model Hypotheses                                          --- *)
(* ------------------------------------------------------------------------ *)

let wp_compute_memory_context model =
  let hypotheses_computer = WpContext.compute_hypotheses model in
  let name = WpContext.MODEL.id model in
  MemoryContext.compute name hypotheses_computer

let wp_warn_memory_context model =
  begin
    WpTarget.iter
      begin fun kf ->
        let hypotheses_computer = WpContext.compute_hypotheses model in
        let model = WpContext.MODEL.id model in
        MemoryContext.warn kf model hypotheses_computer
      end
  end

let wp_insert_memory_context model =
  begin
    WpTarget.iter
      begin fun kf ->
        let hyp_computer = WpContext.compute_hypotheses model in
        let model_id = WpContext.MODEL.id model in
        MemoryContext.add_behavior kf model_id hyp_computer
      end
  end

(* ------------------------------------------------------------------------ *)
(* ---  Printing informations                                           --- *)
(* ------------------------------------------------------------------------ *)

let do_print_index fmt = function
  | Wpo.Axiomatic ax -> Wpo.pp_axiomatics fmt ax
  | Wpo.Function(kf,bhv) -> Wpo.pp_function fmt kf bhv

let rec do_print_parents fmt (node : ProofEngine.node) =
  Option.iter (do_print_parents fmt) (ProofEngine.parent node) ;
  Format.fprintf fmt " - %s@\n" (ProofEngine.title node)

let do_print_current fmt tree =
  match ProofEngine.current tree with
  | `Main -> ()
  | `Internal node | `Leaf(_,node) -> do_print_parents fmt node

let do_print_goal_status fmt (g : Wpo.t) =
  if not (Wpo.is_fully_valid g || Wpo.is_smoke_test g) then
    begin
      do_print_index fmt g.po_idx ;
      Wpo.pp_goal fmt g ;
      if ProofSession.exists g then
        Format.fprintf fmt "Script %a@\n" ProofSession.pp_file
          (ProofSession.filename ~force:false g) ;
      begin
        match ProofEngine.get g with
        | `None | `Script -> ()
        | `Proof | `Saved ->
          let tree = ProofEngine.proof ~main:g in
          match ProofEngine.status tree with
          | `Unproved | `Invalid | `Proved | `Passed ->
            Wpo.pp_goal fmt g
          | `Pending n | `StillResist n ->
            for i = 0 to n-1 do
              Format.fprintf fmt "%tSubgoal %d/%d:@\n" Wpo.pp_flow (succ i) n ;
              ProofEngine.goto tree (`Leaf i) ;
              do_print_current fmt tree ;
              Wpo.pp_goal fmt @@ ProofEngine.head_goal tree
            done
      end ;
      Wpo.pp_flow fmt ;
    end

let do_wp_print_status () =
  begin
    Log.print_on_output
      (fun fmt ->
         Wpo.iter
           ~on_goal:(do_print_goal_status fmt) ()) ;
  end

let do_wp_print () =
  (* Printing *)
  if Wp_parameters.Status.get () then
    do_wp_print_status ()
  else
  if Wp_parameters.Print.get () then
    try
      Wpo.iter ~on_goal:(fun _ -> raise Exit) () ;
      Wp_parameters.result "No proof obligations"
    with Exit ->
      Log.print_on_output
        (fun fmt ->
           Wpo.iter
             ~on_axiomatics:(Wpo.pp_axiomatics fmt)
             ~on_behavior:(Wpo.pp_function fmt)
             ~on_goal:(Wpo.pp_goal_flow fmt) ())

let do_wp_print_for goals =
  if Wp_parameters.Status.get () then
    do_wp_print_status ()
  else
  if Wp_parameters.Print.get () then
    if Bag.is_empty goals
    then Wp_parameters.result "No proof obligations"
    else Log.print_on_output
        (fun fmt -> Bag.iter (Wpo.pp_goal_flow fmt) goals)

let do_wp_report model =
  begin
    let reports = Wp_parameters.Report.get () in
    let jreport = Wp_parameters.OldReportJson.get () in
    if reports <> [] || jreport <> "" then
      begin
        let stats = WpReport.fcstat () in
        begin
          match String.split_on_char ':' jreport with
          | [] | [""] -> ()
          | [joutput] ->
            WpReport.export_json stats ~joutput () ;
          | [jinput;joutput] ->
            WpReport.export_json stats ~jinput ~joutput () ;
          | _ ->
            Wp_parameters.error
              "Invalid format for option -wp-deprecated-report-json"
        end ;
        List.iter (WpReport.export stats) reports ;
      end ;
    if Wp_parameters.MemoryContext.get () then
      wp_warn_memory_context model
  end

(* ------------------------------------------------------------------------ *)
(* ---  Wp Results                                                      --- *)
(* ------------------------------------------------------------------------ *)

let pp_warnings fmt wpo =
  let ws = Wpo.warnings wpo in
  if ws <> [] then
    let n = List.length ws in
    let s = List.exists (fun w -> w.Warning.severe) ws in
    begin
      match s , n with
      | true , 1 -> Format.fprintf fmt " (Degenerated)"
      | true , _ -> Format.fprintf fmt " (Degenerated, %d warnings)" n
      | false , 1 -> Format.fprintf fmt " (Stronger)"
      | false , _ -> Format.fprintf fmt " (Stronger, %d warnings)" n
    end

(* ------------------------------------------------------------------------ *)
(* ---  Prover Stats                                                    --- *)
(* ------------------------------------------------------------------------ *)

module GOALS = Wpo.S.Set

let scheduled = ref 0
let exercised = ref 0
let session = ref GOALS.empty
let smoked_passed = ref 0
let smoked_failed = ref 0

let clear_scheduled () =
  begin
    scheduled := 0 ;
    exercised := 0 ;
    session := GOALS.empty ;
    CfgInfos.trivial_terminates := 0 ;
    WpReached.unreachable_proved := 0 ;
    WpReached.unreachable_failed := 0 ;
  end

let do_list_scheduled goals =
  Bag.iter
    (fun goal ->
       begin
         incr scheduled ;
         session := GOALS.add goal !session ;
       end)
    goals ;
  match !scheduled with
  | 0 -> Wp_parameters.warning ~current:false "No goal generated"
  | 1 -> Wp_parameters.feedback "1 goal scheduled"
  | n -> Wp_parameters.feedback "%d goals scheduled" n

let dkey_prover = Wp_parameters.register_category "prover"

let do_wpo_start goal =
  begin
    incr exercised ;
    if Wp_parameters.has_dkey dkey_prover then
      Wp_parameters.feedback "[Qed] Goal %s preprocessing" (Wpo.get_gid goal) ;
  end

let do_wpo_wait () =
  Wp_parameters.feedback ~ontty:`Transient "[wp] Waiting provers..."

let do_progress goal msg =
  begin
    if !scheduled > 0 then
      let pp = int_of_float (100.0 *. float !exercised /. float !scheduled) in
      let pp = max 0 (min 100 pp) in
      Wp_parameters.feedback ~ontty:`Transient "[%02d%%] %s (%s)"
        pp goal.Wpo.po_sid msg ;
  end

(* ------------------------------------------------------------------------ *)
(* ---  Caching                                                         --- *)
(* ------------------------------------------------------------------------ *)

let do_report_cache_usage mode =
  if !exercised > 0 &&
     not (Wp_parameters.has_dkey VCS.dkey_shell)
  then
    let hits = Cache.get_hits () in
    let miss = Cache.get_miss () in
    if hits <= 0 && miss <= 0 then
      Wp_parameters.result "[Cache] not used"
    else
      Wp_parameters.result "[Cache]%t"
        begin fun fmt ->
          let sep = ref " " in
          let pp_cache fmt n job =
            if n > 0 then
              ( Format.fprintf fmt "%s%s:%d" !sep job n ; sep := ", " ) in
          match mode with
          | Cache.NoCache -> ()
          | Cache.Replay ->
            pp_cache fmt hits "found" ;
            pp_cache fmt miss "missed" ;
            Format.pp_print_newline fmt () ;
          | Cache.Offline ->
            pp_cache fmt hits "found" ;
            pp_cache fmt miss "failed" ;
            Format.pp_print_newline fmt () ;
          | Cache.Update | Cache.Cleanup ->
            pp_cache fmt hits "found" ;
            pp_cache fmt miss "updated" ;
            Format.pp_print_newline fmt () ;
          | Cache.Rebuild ->
            pp_cache fmt hits "replaced" ;
            pp_cache fmt miss "updated" ;
            Format.pp_print_newline fmt () ;
        end

(* -------------------------------------------------------------------------- *)
(* --- Prover JSON Results                                                --- *)
(* -------------------------------------------------------------------------- *)

let pstats_to_json (p,r) : Json.t = `Assoc [
    "prover", `String (VCS.name_of_prover p) ;
    "time", `Float r.Stats.time ;
    "success", `Int (truncate r.Stats.success) ;
  ]

let stats_to_json g (s : Stats.stats) : Json.t =
  let smoke = Wpo.is_smoke_test g in
  let target = Wpo.get_target g in
  let source = fst (Property.location target) in
  let script = match ProofSession.get g with
    | NoScript -> []
    | Script file | Deprecated file -> [ "script", `String (file :> string) ]
  in
  let index =
    match g.po_idx with
    | Axiomatic None -> []
    | Axiomatic (Some ax) ->
      [ "axiomatic", `String ax ]
    | Function(kf,None) ->
      [ "function", `String (Kernel_function.get_name kf) ]
    | Function(kf,Some bhv) -> [
        "function", `String (Kernel_function.get_name kf);
        "behavior", `String bhv ;
      ] in
  let subgoals = Stats.subgoals s in
  let subgoals = if subgoals > 1 then ["subgoals", `Int subgoals] else [] in
  `Assoc
    ([
      "goal", `String g.po_gid ;
      "property", `String (Property.Names.get_prop_name_id target) ;
      "file", `String (source.pos_path :> string) ;
      "line", `Int source.pos_lnum ;
    ] @ index @ [
        "smoke", `Bool smoke ;
        "passed", `Bool (Wpo.is_passed g) ;
        "verdict", `String (VCS.name_of_verdict s.best) ;
      ] @ script @ [
        "provers", `List (List.map pstats_to_json s.provers) ;
      ] @ subgoals @
      List.filter (function (_,`Int n) -> n > 0 | _ -> true) [
        "tactics", `Int s.tactics;
        "proved", `Int s.proved;
        "timeout", `Int s.timeout;
        "unknown", `Int s.unknown ;
        "failed", `Int s.failed ;
        "cached", `Int s.cached ;
      ])

let do_report_json () =
  let file = Wp_parameters.ReportJson.get () in
  if not (Filepath.Normalized.is_empty file) then
    let json = List.rev @@
      GOALS.fold
        (fun g json ->
           let s = ProofEngine.consolidated g in
           let js = stats_to_json g s in
           js :: json
        ) !session [] in
    Json.save_file file (`List json)

(* -------------------------------------------------------------------------- *)
(* --- Prover Results                                                     --- *)
(* -------------------------------------------------------------------------- *)

type stats = {
  proofs: Stats.stats ;
  tactic: Stats.stats ;
  updated: (Wpo.t * Filepath.Normalized.t * Json.t) list;
  incomplete: (Wpo.t * Filepath.Normalized.t * Json.t) list;
  removed: (Wpo.t * Filepath.Normalized.t) list;
}

let do_wpo_result goal prover res =
  if VCS.is_verdict res && prover = VCS.Qed then
    do_progress goal "Qed"

let pp_hasmodel fmt goal =
  if Wp_parameters.CounterExamples.get () then
    let results = Wpo.get_results goal in
    let model =
      List.exists
        (fun (_,r) -> not @@ Probe.Map.is_empty r.VCS.prover_model)
        results in
    if model then Format.fprintf fmt " (Model)" else
      let ce_variant =
        List.exists
          (fun (p,_) -> VCS.has_counter_examples p)
          results in
      if ce_variant then Format.fprintf fmt " (No Model)"

let do_report_stats ~shell ~cache ~smoke goal (stats : Stats.stats) =
  let status =
    if smoke then
      match stats.best with
      | Valid -> "[Failed] (Doomed)"
      | Failed ->  "[Failure] (Solver Error)"
      | NoResult | Computing _ -> "[NoResult] (Unknown)"
      | (Unknown | Timeout | Stepout | Invalid)
        when shell -> "[Passed] (Unsuccess)"
      | Unknown -> "[Passed] (Unknown)"
      | Timeout -> "[Passed] (Timeout)"
      | Stepout -> "[Passed] (Stepout)"
      | Invalid -> "[Passed] (Invalid)"
    else
      match stats.best with
      | NoResult when shell -> "[NoResult]"
      | NoResult | Computing _ -> ""
      | Valid -> "[Valid]"
      | Failed ->  "[Failure]"
      | (Invalid | Unknown | Timeout | Stepout) when shell -> "[Unsuccess]"
      | Unknown -> "[Unknown]"
      | Timeout -> "[Timeout]"
      | Stepout -> "[Stepout]"
      | Invalid -> "[Invalid]"
  in if status <> "" then
    Wp_parameters.feedback "%s %s%a%a%a"
      status (Wpo.get_gid goal) (Stats.pp_stats ~shell ~cache) stats
      pp_hasmodel goal pp_warnings goal

let do_wpo_success ~shell ~cache goal success =
  if Wp_parameters.Generate.get () then
    match success with
    | None -> ()
    | Some prover ->
      Wp_parameters.feedback ~ontty:`Silent
        "[Generated] Goal %s (%a)" (Wpo.get_gid goal) VCS.pp_prover prover
  else
    let gui = Wp_parameters.is_interactive () in
    let smoke = Wpo.is_smoke_test goal in
    let cstats = ProofEngine.consolidated goal in
    let success = Wpo.is_passed goal in
    begin
      if smoke then
        (if Wpo.is_passed goal
         then incr smoked_passed
         else incr smoked_failed) ;
      if gui || shell || not success then
        do_report_stats ~shell ~cache goal ~smoke cstats ;
      if smoke then
        begin
          let proof, target = Wpo.get_proof goal in
          if proof <> `Passed then
            let source = fst (Property.location target) in
            Wp_parameters.warning ~once:true ~source "Failed smoke-test"
        end ;
    end

let do_report_scheduled (stats : stats) =
  if Wp_parameters.Generate.get () then
    let plural = if !exercised > 1 then "s" else "" in
    Wp_parameters.result "%d goal%s generated" !exercised plural
  else
    let total =
      !scheduled +
      !WpReached.unreachable_failed +
      !WpReached.unreachable_proved +
      !CfgInfos.trivial_terminates in
    if total > 0 then
      begin
        let unreachable = !WpReached.unreachable_proved in
        let terminating = !CfgInfos.trivial_terminates in
        let passed = GOALS.fold
            (fun g n ->
               if Wpo.is_passed g then succ n else n
            ) !session (unreachable + terminating) in
        let cache = Cache.get_mode () in
        if Cache.is_active cache then do_report_cache_usage cache ;
        let shell = Wp_parameters.has_dkey VCS.dkey_shell in
        let lines = ref [] in
        let none = fun _fmt -> () in
        let add_line title count pp =
          lines := (title,count,pp) :: !lines in
        if terminating > 0 then add_line "Terminating" terminating none ;
        if unreachable > 0 then add_line "Unreachable" unreachable none ;
        let proofs = stats.proofs in
        List.iter
          (fun (p,s) ->
             let name = VCS.title_of_prover p in
             let success = truncate s.Stats.success in
             if success > 0 || (not shell && p = Qed) then
               add_line name success (fun fmt ->
                   if p = Tactical then
                     Stats.pp_stats ~shell ~cache fmt stats.tactic
                   else
                   if not shell then Stats.pp_pstats fmt s
                 )
          ) proofs.provers ;
        let failed = proofs.failed in
        if failed > 0 then add_line "Failed" failed none ;
        if shell then
          begin
            let n = Stats.subgoals proofs - proofs.proved - proofs.failed in
            if n > 0 then add_line "Unsuccess" n none
          end
        else
          begin
            if proofs.timeout > 0 then add_line "Timeout" proofs.timeout none ;
            if proofs.unknown > 0 then add_line "Unknown" proofs.unknown none ;
          end ;
        let smoked = !smoked_failed + !smoked_passed in
        if smoked > 0 then
          add_line "Smoke Tests" !smoked_passed
            (fun fmt -> Format.fprintf fmt " / %d" smoked) ;
        if proofs.noresult > 0 then add_line "Missing" proofs.noresult none ;
        let iter f = List.iter f (List.rev !lines) in
        let title (p,_,_) = p in
        let pp_title fmt p = Format.fprintf fmt "%s:" p in
        let pp_item pp fmt (a,n,msg) =
          Format.fprintf fmt "%a %4d%t@\n" pp a n msg in
        Wp_parameters.result "%t"
          begin fun fmt ->
            Format.fprintf fmt "Proved goals: %4d / %d@\n" passed total ;
            Pretty_utils.pp_items
              ~min:12 ~align:`Left ~title ~iter ~pp_title ~pp_item fmt ;
          end ;
      end

let do_list_scheduled_result stats =
  begin
    do_report_scheduled stats ;
    do_report_json () ;
    clear_scheduled () ;
  end

(* ------------------------------------------------------------------------ *)
(* ---  Proving                                                         --- *)
(* ------------------------------------------------------------------------ *)

type script = {
  mutable proverscript : bool ;
  mutable strategies : bool ;
  scratch : bool ;
  update : bool ;
  stdout : bool ;
  mutable depth : int ;
  mutable width : int ;
  mutable backtrack : int ;
  mutable auto : Strategy.heuristic list ;
  mutable provers : (VCS.mode * VCS.prover) list ;
}

let spawn_wp_proofs ~script goals =
  if script.proverscript || script.provers<>[] then
    begin
      let server = ProverTask.server () in
      ignore (Wp_parameters.Share.get_dir "."); (* To prevent further errors *)
      let shell = Wp_parameters.has_dkey VCS.dkey_shell in
      let cache = Cache.get_mode () in
      Bag.iter
        (fun goal ->
           if  script.proverscript
            && not (Wpo.is_trivial goal)
            && (script.auto <> [] ||
                script.strategies ||
                ProofSession.exists goal ||
                Wp_parameters.DefaultStrategies.get () <> [] ||
                ProofStrategy.hints goal <> [])
           then
             ProverScript.spawn
               ~failed:false
               ~scratch:script.scratch
               ~strategies:script.strategies
               ~auto:script.auto
               ~depth:script.depth
               ~width:script.width
               ~backtrack:script.backtrack
               ~provers:(List.map snd script.provers)
               ~start:do_wpo_start
               ~progress:do_progress
               ~result:do_wpo_result
               ~success:(do_wpo_success ~shell ~cache)
               goal
           else
             Prover.spawn goal
               ~delayed:false
               ~start:do_wpo_start
               ~progress:do_progress
               ~result:do_wpo_result
               ~success:(do_wpo_success ~shell ~cache)
               script.provers
        ) goals ;
      Task.on_server_wait server do_wpo_wait ;
      Task.launch server
    end

let get_prover_names () =
  match Wp_parameters.Provers.get () with
  | [] -> [ "Alt-Ergo" ] | pnames -> pnames

let compute_provers ~mode ~script =
  script.provers <- List.fold_right
      begin fun pname prvs ->
        match VCS.parse_prover pname with
        | None -> prvs
        | Some VCS.Tactical ->
          script.proverscript <- true ;
          if pname = "tip" then script.strategies <- true ;
          prvs
        | Some prover ->
          let pmode = if VCS.is_auto prover then VCS.Batch else mode in
          (pmode , prover) :: prvs
      end (get_prover_names ()) []

let dump_strategies =
  let once = ref true in
  fun () ->
    if !once then
      ( once := false ;
        Wp_parameters.result "Registered strategies for -wp-auto:%t"
          (fun fmt ->
             Strategy.iter (fun h ->
                 Format.fprintf fmt "@\n  '%s': %s" h#id h#title
               )))

let default_script_mode () = {
  provers = [] ;
  proverscript = false ;
  strategies = false ;
  update = ProofSession.saving_mode () ;
  scratch = ProofSession.scratch_mode () ;
  stdout = Wp_parameters.ScriptOnStdout.get ();
  depth=0 ; width = 0 ; backtrack = 0 ; auto=[] ;
}

let compute_auto ~script =
  script.auto <- [] ;
  script.width <- Wp_parameters.AutoWidth.get () ;
  script.depth <- Wp_parameters.AutoDepth.get () ;
  script.backtrack <- max 0 (Wp_parameters.BackTrack.get ()) ;
  let auto = Wp_parameters.Auto.get () in
  if script.depth <= 0 || script.width <= 0 then
    ( if auto <> [] then
        Wp_parameters.feedback
          "Auto-search deactivated because of 0-depth or 0-width" )
  else
    begin
      List.iter
        (fun id ->
           if id = "?" then dump_strategies ()
           else
             try script.auto <- Strategy.lookup ~id :: script.auto
             with Not_found ->
               Wp_parameters.error ~current:false
                 "Strategy -wp-auto '%s' unknown (ignored)." id
        ) auto ;
      script.auto <- List.rev script.auto ;
      if script.auto <> [] then script.proverscript <- true ;
    end

type scripts =
  | Useless
  | Scripts of { complete : bool ; scripts : ProofScript.alternative list }

let do_compute_scripts ~smoke goal results : scripts =
  let autoproof (p,r) =
    (p=VCS.Qed) || (VCS.is_auto p && VCS.is_valid r && VCS.autofit r) in
  if List.exists autoproof results then Useless
  else
    let scripts = ProofEngine.script (ProofEngine.proof ~main:goal) in
    if scripts = [] then Useless
    else
      let complete = function
        | ProofScript.Prover(p,r) -> VCS.is_auto p && VCS.is_valid r
        | ProofScript.Tactic(n,_,_) -> n=0
        | ProofScript.Error _ -> false in
      let winning = List.filter complete scripts in
      if winning <> [] then Scripts { complete=true ; scripts = winning }
      else if smoke then Useless else Scripts { complete=false ; scripts }

let do_collect_session goals =
  let removed = ref [] in
  let updated = ref [] in
  let incomplete = ref [] in
  let proofs = ref Stats.empty in
  let tactic = ref Stats.empty in
  let add r s = r := Stats.add !r s in
  Bag.iter
    begin fun goal ->
      let smoke = Wpo.is_smoke_test goal in
      let results = Wpo.get_results goal in
      let file = ProofSession.filename ~force:false goal in
      match do_compute_scripts ~smoke goal results with
      | Useless ->
        let provers = List.filter (fun (p,_) -> VCS.is_prover p) results in
        add proofs @@ Stats.results ~smoke provers ;
        if ProofSession.exists goal then
          removed := (goal, file) :: !removed
      | Scripts { complete ; scripts } ->
        add proofs @@ Stats.results ~smoke results ;
        add tactic @@ ProofEngine.consolidated goal ;
        let json = ProofScript.encode scripts in
        let accu = if complete then updated else incomplete in
        accu := (goal, file, json) :: !accu ;
    end goals ;
  {
    updated = !updated ;
    incomplete = !incomplete ;
    removed = !removed ;
    proofs = !proofs ;
    tactic = !tactic ;
  }

let do_update_session script session =
  let stdout = script.stdout in
  List.iter
    begin fun (g, _, s) ->
      (* we always mark existing scripts *)
      ProofSession.mark g ;
      if script.update then ProofSession.save ~stdout g s
    end
    session.updated ;
  List.iter
    begin fun (g, _, s) ->
      (* we mark new incomplete scripts only if we save such files *)
      if script.update then
        (ProofSession.mark g ; ProofSession.save ~stdout g s)
    end
    session.incomplete ;
  List.iter (fun (g, _) -> ProofSession.remove g) session.removed ;
  ()

let do_show_session updated_session session =
  let show enabled kind dkey file =
    if enabled then
      Wp_parameters.result ~dkey "[%s] %a" kind Filepath.Normalized.pretty file
  in
  (* Note: we display new (in)valid scripts only when updating *)
  List.iter
    (fun (_,f,_) -> show updated_session "UPDATED" dkey_script_updated f)
    session.updated ;
  List.iter
    (fun (_,f,_) -> show updated_session "INCOMPLETE" dkey_script_incomplete f)
    session.incomplete ;
  let txt_removed = if updated_session then "REMOVED" else "UNUSED" in
  List.iter
    (fun (_,f) -> show true txt_removed dkey_script_removed f)
    session.removed ;

  let r = List.length session.removed in
  let u = List.length session.updated in
  let f = List.length session.incomplete in

  (* Note: we display new (in)valid scripts only when updating *)
  if (updated_session && (f > 0 || u > 0)) || r > 0 then
    let updated_s =
      let s = if u > 1 then "s" else "" in
      if u = 0 || (not updated_session) then ""
      else Format.asprintf "\n - %d new valid script%s" u s
    in
    let invalid_s =
      let s = if f > 1 then "s" else "" in
      if f = 0 || (not updated_session) then ""
      else Format.asprintf "\n - %d new script%s to complete" f s
    in
    let removed_s =
      let s = if r > 1 then "s" else "" in
      let txt_removed = String.lowercase_ascii txt_removed in
      if r = 0 then ""
      else Format.asprintf "\n - %d script%s %s (now automated)" r s txt_removed
    in
    Wp_parameters.result
      "%s%s%s%s"
      (if updated_session then "Updated session" else "Session can be updated")
      removed_s updated_s invalid_s

let do_wpo_display goal =
  let result = if Wpo.is_trivial goal then "trivial" else "not tried" in
  Wp_parameters.feedback "Goal %s : %s" (Wpo.get_gid goal) result

let do_wp_proofs ?provers ?tip (goals : Wpo.t Bag.t) =
  let script = default_script_mode () in
  let mode = VCS.parse_mode (Wp_parameters.Interactive.get ()) in
  compute_provers ~mode ~script ;
  compute_auto ~script ;
  ProofStrategy.typecheck () ;
  begin match provers with None -> () | Some prvs ->
    script.provers <- List.map (fun dp -> VCS.Batch , VCS.Why3 dp) prvs
  end ;
  begin match tip with None -> () | Some strategies ->
    script.proverscript <- true ;
    script.strategies <- strategies ;
  end ;
  let spawned = script.proverscript || script.provers <> [] in
  begin
    if spawned then do_list_scheduled goals ;
    spawn_wp_proofs ~script goals ;
    if spawned then
      begin
        let stats = do_collect_session goals in
        do_list_scheduled_result stats ;
        do_update_session script stats ;
        do_show_session script.update stats ;
      end
    else
    if not (Wp_parameters.Print.get () || Wp_parameters.Status.get ())
    then Bag.iter do_wpo_display goals
  end

(* registered at frama-c (normal) exit *)
let do_cache_cleanup () =
  begin
    Cache.cleanup_cache () ;
    let removed = Cache.get_removed () in
    if removed > 0 &&
       not (Wp_parameters.has_dkey VCS.dkey_shell)
    then
      Wp_parameters.result "[Cache] removed:%d" removed
  end

(* ------------------------------------------------------------------------ *)
(* ---  Command-line Entry Points                                       --- *)
(* ------------------------------------------------------------------------ *)

let dkey_builtins = Wp_parameters.register_category "builtins"
let dkey_logicusage = Wp_parameters.register_category "logicusage"
let dkey_refusage = Wp_parameters.register_category "refusage"
let dkey_wp_rte = Wp_parameters.register_category "wp-rte"

let cmdline_run () =
  begin
    if Wp_parameters.CachePrint.get () then
      Wp_parameters.feedback "Cache directory: %s" (Cache.get_dir ()) ;
    let fct = Wp_parameters.get_fct () in
    if fct <> Wp_parameters.Fct_none then
      begin
        Wp_parameters.feedback ~ontty:`Feedback "Running WP plugin...";
        let generator = Generator.create () in
        let model = generator#model in
        Ast.compute ();
        Dyncall.compute ();
        if Wp_parameters.has_dkey dkey_wp_rte then
          begin
            if Wp_parameters.RTE.get () then
              WpRTE.generate_all model ;
          end ;
        if Wp_parameters.has_dkey dkey_logicusage then
          begin
            LogicUsage.compute ();
            LogicUsage.dump ();
          end ;
        if Wp_parameters.has_dkey dkey_refusage then
          begin
            RefUsage.compute ();
            RefUsage.dump ();
          end ;
        let bhv = Wp_parameters.Behaviors.get () in
        let prop = Wp_parameters.Properties.get () in
        (* TODO entry point *)
        if Wp_parameters.has_dkey dkey_builtins then
          begin
            WpContext.on_context (model,WpContext.Global)
              LogicBuiltins.dump ();
          end ;
        WpTarget.compute model ~fct ~bhv ~prop () ;
        wp_compute_memory_context model ;
        if Wp_parameters.CheckMemoryContext.get () then
          wp_insert_memory_context model ;
        let goals = generator#compute_main ~fct ~bhv ~prop () in
        do_wp_proofs goals ;
        begin
          if fct <> Wp_parameters.Fct_all then
            do_wp_print_for goals
          else
            do_wp_print () ;
        end ;
        do_wp_report model ;
      end
  end

(* ------------------------------------------------------------------------ *)
(* ---  Tracing WP Invocation                                           --- *)
(* ------------------------------------------------------------------------ *)

let pp_wp_parameters fmt =
  begin
    Format.pp_print_string fmt "# frama-c -wp" ;
    if Wp_parameters.RTE.get () then Format.pp_print_string fmt " -wp-rte" ;
    let spec = Wp_parameters.Model.get () in
    if spec <> [] && spec <> ["Typed"] then
      ( let descr = Factory.descr (Factory.parse spec) in
        Format.fprintf fmt " -wp-model '%s'" descr ) ;
    let dt = Wp_parameters.Timeout.get_default () in
    let tm = Wp_parameters.Timeout.get () in
    if tm <> dt then Format.fprintf fmt " -wp-timeout %d" tm ;
    let st = Wp_parameters.Steps.get () in
    if st > 0 then Format.fprintf fmt " -wp-steps %d" st ;
    if not (Kernel.SignedOverflow.get ()) then
      Format.pp_print_string fmt " -no-warn-signed-overflow" ;
    if Kernel.UnsignedOverflow.get () then
      Format.pp_print_string fmt " -warn-unsigned-overflow" ;
    if Kernel.SignedDowncast.get () then
      Format.pp_print_string fmt " -warn-signed-downcast" ;
    if Kernel.UnsignedDowncast.get () then
      Format.pp_print_string fmt " -warn-unsigned-downcast" ;
    if not (Wp_parameters.Volatile.get ()) then
      Format.pp_print_string fmt " -wp-no-volatile" ;
    Format.pp_print_string fmt " [...]" ;
    Format.pp_print_newline fmt () ;
  end

let () = Cmdline.run_after_setting_files
    (fun _ ->
       if Wp_parameters.has_dkey VCS.dkey_shell then
         Log.print_on_output pp_wp_parameters)

(* -------------------------------------------------------------------------- *)
(* --- Prover Configuration & Detection                                   --- *)
(* -------------------------------------------------------------------------- *)

let () = Cmdline.run_after_configuring_stage Why3Provers.configure

let do_prover_detect () =
  if Wp_parameters.Detect.get () && not @@ Wp_parameters.is_interactive () then
    let provers = Why3Provers.provers () in
    if provers = [] then
      Wp_parameters.result "No Why3 provers detected."
    else
      let open Why3.Whyconf in
      let shortcuts = get_prover_shortcuts (Why3Provers.config ()) in
      let print_prover_shortcuts_for fmt p =
        Why3.Wstdlib.Mstr.iter
          (fun name p' -> if Prover.equal p p' then
              Format.fprintf fmt "%s|" name)
          shortcuts in
      List.iter
        (fun p ->
           Wp_parameters.result "Prover %10s %-6s [%a%s]"
             p.prover_name p.prover_version
             print_prover_shortcuts_for p
             (Why3Provers.ident_wp p)
        ) provers

(* ------------------------------------------------------------------------ *)
(* --- Tactic Searching                                                 --- *)
(* ------------------------------------------------------------------------ *)

let pp_field fmt pp (fd : 'a Tactical.field) =
  let s = Tactical.signature fd in
  Format.fprintf fmt "@\nParameter %S:" s.vid ;
  if s.title <> "" then Format.fprintf fmt "@\n  Title: %s" s.title ;
  if s.descr <> "" then Format.fprintf fmt "@\n  Descr: %s" s.descr ;
  Format.fprintf fmt "@\n  Default: %a" pp (Tactical.default fd)

let pp_parameter fmt (p : Tactical.parameter) =
  match p with
  | Checkbox fd ->
    pp_field fmt Format.pp_print_bool fd
  | Spinner(fd,rg) ->
    pp_field fmt Format.pp_print_int fd ;
    begin match rg.vmin , rg.vmax with
      | None,None -> ()
      | Some a,None -> Format.fprintf fmt "@\n  Range: %d.." a
      | None,Some b -> Format.fprintf fmt "@\n  Range: ..%d" b
      | Some a,Some b -> Format.fprintf fmt "@\n  Range: %d..%d" a b
    end
  | Composer(fd,_) ->
    pp_field fmt Tactical.pp_selection fd
  | Selector(fd,items,eq) ->
    pp_field fmt
      (fun fmt v ->
         List.iter
           (fun (item : _ Tactical.named) ->
              if eq v item.value then Format.fprintf fmt "%S" item.vid
           ) items
      ) fd ;
    List.iter
      (fun (item : _ Tactical.named) ->
         Format.fprintf fmt "@\n  Value %S: %s" item.vid item.title ;
         if item.descr <> "" then Format.fprintf fmt " (%s)" item.descr ;
      ) items
  | Search(fd,_,_) ->
    pp_field fmt
      (fun fmt s ->
         match s with
         | None -> Format.pp_print_string fmt "-"
         | Some v -> Format.fprintf fmt "%S" v.Tactical.title
      ) fd

let do_search_tactics () =
  let ts = Wp_parameters.Tactics.get () in
  if List.mem "?" ts then
    Wp_parameters.result "@[<hov 2>Registered tactics:%t@]"
      begin fun fmt ->
        Tactical.iter (fun t -> Format.fprintf fmt "@ %s" t#id) ;
      end ;
  if ts <> [] then
    Tactical.iter
      begin fun t ->
        if List.mem t#id ts then
          Wp_parameters.result
            "Tactic %S:@\n\
             Title: @[<h>%s@]@\n\
             Descr: @[<h>%s@]%t"
            t#id t#title t#descr
            (fun fmt -> List.iter (pp_parameter fmt) t#params)
      end

(* ------------------------------------------------------------------------ *)
(* ---  Main Entry Points                                               --- *)
(* ------------------------------------------------------------------------ *)

let step_finally ~finally f x =
  let r = try f x with e -> finally () ; raise e in
  finally () ; r

let rec try_sequence jobs () = match jobs with
  | [] -> ()
  | head :: tail ->
    step_finally ~finally:(try_sequence tail) head ()

let sequence jobs () =
  if Wp_parameters.has_dkey dkey_raised
  then List.iter (fun f -> f ()) jobs
  else try_sequence jobs ()

let prepare_scripts () =
  if Wp_parameters.PrepareScripts.get () then begin
    Wp_parameters.feedback "Prepare" ;
    ProofSession.reset_marks () ;
    Wp_parameters.PrepareScripts.clear ()
  end

let finalize_scripts () =
  if Wp_parameters.FinalizeScripts.get () then begin
    Wp_parameters.feedback "Finalize" ;
    ProofSession.remove_unmarked_files
      ~dry:(Wp_parameters.DryFinalizeScripts.get()) ;
    Wp_parameters.FinalizeScripts.clear ()
  end

let tracelog () =
  let active_keys = Wp_parameters.get_debug_keys () in
  if active_keys <> [] then begin
    let pp_sep fmt () = Format.pp_print_string fmt "," in
    Wp_parameters.(
      debug "Logging keys: %a."
        (Format.pp_print_list ~pp_sep pp_category) active_keys)
  end

let main =
  sequence [
    (fun () -> Wp_parameters.debug ~dkey:dkey_main "Start WP plugin...@.") ;
    do_prover_detect ;
    do_search_tactics ;
    prepare_scripts ;
    cmdline_run ;
    tracelog ;
    finalize_scripts ;
    Wp_parameters.reset ;
    (fun () -> Wp_parameters.debug ~dkey:dkey_main "Stop WP plugin...@.") ;
  ]

let () = Cmdline.at_normal_exit do_cache_cleanup
let () = Boot.Main.extend main

(* ------------------------------------------------------------------------ *)
