(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let compute_probes ~ce ~pid goal =
  if ce then Wpo.GOAL.compute_probes ~pid goal else Probe.Map.empty

let task_of_wpo ~ce wpo =
  let v = wpo.Wpo.po_formula in
  let pid = wpo.Wpo.po_pid in
  let prop = Wpo.GOAL.compute_proof ~pid ~opened:ce v.goal in
  let probes = compute_probes ~ce ~pid v.goal in
  ExportWhy3.cc_task ~pid ?axioms:v.axioms ~probes prop, probes

(* -------------------------------------------------------------------------- *)
(* --- Prover Task                                                        --- *)
(* -------------------------------------------------------------------------- *)

let prover_task env prover task =
  let config = Why3Env.config () in
  let prover_config = Why3.Whyconf.get_prover_config config prover in
  let drv = Why3.Driver.load_driver_for_prover (Why3.Whyconf.get_main config)
      env prover_config in
  drv , prover_config , Why3.Driver.prepare_task drv task

(* -------------------------------------------------------------------------- *)
(* --- Prover Call                                                        --- *)
(* -------------------------------------------------------------------------- *)

let dkey = Wp_parameters.register_category "prover"
let dkey_pp_task = Wp_parameters.register_category "prover:pp_task"

let dkey_model =
  Wp_parameters.register_category
    ~help:"Counter examples model variable"
    "why3:model"

type prover_call = {
  prover : Why3Env.prover ;
  call : Why3.Call_provers.prover_call ;
  steps : int option ;
  timeout : float ;
  mutable timeover : float option ;
  mutable interrupted : bool ;
  mutable killed : bool ;
}

let has_model_attr attrs =
  Why3.Ident.Sattr.fold_left (fun acc (e:Why3.Ident.attribute) ->
      match String.remove_prefix "model_trace:" e.attr_string with
      | None -> acc
      | Some _ as a -> a
    ) None attrs

let debug_model (res:Why3.Call_provers.prover_result) =
  Wp_parameters.debug ~dkey:dkey_model "%t"
    begin fun fmt ->
      List.iter
        begin fun (res,model) ->
          Format.fprintf fmt "@[<hov 2>model %a: %a@]@\n"
            Why3.Call_provers.print_prover_answer res
            (Why3.Model_parser.print_model
               ~print_attrs:true) model
        end
        res.pr_models
    end

let get_model probes (res:Why3.Call_provers.prover_result) =
  if Wp_parameters.has_dkey dkey_model && not @@ Probe.Map.is_empty probes then
    debug_model (res:Why3.Call_provers.prover_result);
  (* we take the second model because it should be the most precise?? *)
  match Why3.Check_ce.select_model_last_non_empty res.pr_models with
  | None -> Probe.Map.empty
  | Some model ->
    let index = Hashtbl.create 0 in
    let elements = Why3.Model_parser.get_model_elements model in
    List.iter
      (fun (e:Why3.Model_parser.model_element) ->
         match has_model_attr e.me_attrs with
         | None -> ()
         | Some id -> Hashtbl.add index id e.me_concrete_value)
      elements ;
    Probe.Map.filter_map
      (fun (p:Probe.t) _ ->
         let id = string_of_int p.id in
         try Some (Hashtbl.find index id)
         with Not_found -> None
      ) probes

let ping_prover_call ~config ~probes p =
  match Why3.Call_provers.query_call p.call with
  | NoUpdates
  | ProverStarted ->
    let () =
      if p.timeout > 0.0 then
        match p.timeover with
        | None ->
          let started = Unix.time () in
          p.timeover <- Some (started +. 2.0 +. p.timeout)
        | Some timeout ->
          let time = Unix.time () in
          if time > timeout then
            begin
              Wp_parameters.debug ~dkey
                "Hard Kill (late why3server timeout)" ;
              p.interrupted <- true ;
              Why3.Call_provers.interrupt_call ~config p.call ;
            end
    in Task.Wait 100
  | InternalFailure exn ->
    let msg = Format.asprintf "@[<hov 2>%a@]"
        Why3.Exn_printer.exn_printer exn in
    Task.Return (Task.Result (VCS.failed msg))
  | ProverInterrupted -> Task.(Return Canceled)
  | ProverFinished _ when p.killed -> Task.(Return Canceled)
  | ProverFinished pr ->
    let r =
      let time = max Rformat.epsilon pr.pr_time in
      match pr.pr_answer with
      | Timeout -> VCS.timeout time
      | Valid -> VCS.result ~time ~steps:pr.pr_steps VCS.Valid
      | OutOfMemory -> VCS.failed "out of memory"
      | StepLimitExceeded -> VCS.result ?steps:p.steps VCS.Stepout
      | Invalid ->
        debug_model pr;
        VCS.result ~time:pr.pr_time ~steps:pr.pr_steps
          ~model:(get_model probes pr) VCS.Invalid
      | Unknown _ ->
        debug_model pr;
        VCS.result ~model:(get_model probes pr) VCS.Unknown
      | _ when p.interrupted -> VCS.timeout p.timeout
      | Failure msg | HighFailure msg -> VCS.failed msg
    in
    Wp_parameters.debug ~dkey
      "@[@[Why3 result for %a:@] @[%a@] and @[%a@]@."
      Why3.Whyconf.print_prover p.prover
      (Why3.Call_provers.print_prover_result ~json:false) pr
      VCS.pp_result r;
    Task.Return (Task.Result r)

let call_prover_task ~timeout ~steps ~config ~probes prover call =
  Wp_parameters.debug ~dkey "Why3 run prover %a with timeout %f, steps %d@."
    Why3.Whyconf.print_prover prover
    (Option.value ~default:(0.0) timeout)
    (Option.value ~default:0 steps) ;
  let timeout = match timeout with None -> 0.0 | Some tlimit -> tlimit in
  let pcall = {
    call ; prover ;
    killed = false ;
    interrupted = false ;
    steps ; timeout ; timeover = None ;
  } in
  let ping = function
    | Task.Kill ->
      pcall.killed <- true ;
      Why3.Call_provers.interrupt_call ~config call ;
      Task.Yield
    | Task.Coin -> ping_prover_call ~config ~probes pcall
  in
  Task.async ping

(* -------------------------------------------------------------------------- *)
(* --- Batch Prover                                                       --- *)
(* -------------------------------------------------------------------------- *)

let output_task wpo drv ?(script : Filepath.t option) prover task =
  let file =
    Wpo.DISK.file_goal ~pid:wpo.Wpo.po_pid ~model:wpo.Wpo.po_model drv prover in
  let open Filesystem.Operators in
  let$ fmt = Filesystem.with_formatter_exn file in
  let pp_header fmt msg data =
    match Filepath.extension file with
    | ".mlw" | ".why" | ".v" ->
      Format.fprintf fmt "(* %s %s *)@\n" msg data
    | ".smt2" | ".psmt2" ->
      Format.fprintf fmt "; %s %s@\n" msg data
    | _ -> ()
  in
  pp_header fmt "WP Task for Prover" @@ Why3Env.ident_why3 prover ;
  let old = Option.map
      (fun fscript ->
         let hash = Filesystem.digest fscript in
         pp_header fmt "WP Script" hash ;
         open_in (Filepath.to_string_abs fscript)
      ) script in
  let _ = Why3.Driver.print_task_prepared ?old drv fmt task in
  Option.iter close_in old


let digest_task wpo drv ?(script : Filepath.t option) prover task =
  output_task wpo drv ?script prover task;
  Filesystem.digest @@
  Wpo.DISK.file_goal ~pid:wpo.Wpo.po_pid ~model:wpo.Wpo.po_model drv prover

let run_batch pconf driver ~config
    ?(script : Filepath.t option)
    ~timeout ~steplimit ~memlimit
    ?(probes=Probe.Map.empty)
    prover task =
  let steps = match steplimit with Some 0 -> None | _ -> steplimit in
  let limits =
    let config = Why3.Whyconf.get_main @@ Why3Env.config () in
    let config_mem = Why3.Whyconf.memlimit config in
    let config_time = Why3.Whyconf.timelimit config in
    let config_steps = Why3.Call_provers.empty_limits.limit_steps in
    let limit_mem =
      if not @@ Why3Env.is_auto prover
      then 0
      else Option.value ~default:config_mem memlimit
    in
    Why3.Call_provers.{
      limit_time = Option.value ~default:config_time timeout;
      limit_steps = Option.value ~default:config_steps steps;
      limit_mem;
    } in
  let with_steps = match steps, pconf.Why3.Whyconf.command_steps with
    | None, _ -> false
    | Some _, Some _ -> true
    | Some _, None ->
      Wp_parameters.warning ~once:true ~current:false
        "%a does not support steps limit (ignored option)"
        Why3.Whyconf.print_prover prover ;
      false in
  let steps = if with_steps then steps else None in
  let command = Why3.Whyconf.get_complete_command pconf ~with_steps in
  Wp_parameters.debug ~dkey "Prover command %S" command ;
  let inplace = if script <> None then Some true else None in
  let call =
    Why3.Driver.prove_task_prepared
      ?old:(Option.map Filepath.to_string_abs script) ?inplace
      ~command ~limits ~config driver task in
  call_prover_task ~config ~timeout ~steps ~probes prover call

(* -------------------------------------------------------------------------- *)
(* --- Interactive Prover (Coq)                                           --- *)
(* -------------------------------------------------------------------------- *)

let editor_mutex = Task.mutex ()

let editor_command pconf =
  let config = Why3Env.config () in
  try
    let prover = pconf.Why3.Whyconf.prover in
    let ed_id = Why3.Whyconf.get_prover_editor config prover in
    let ed = Why3.Whyconf.editor_by_id config ed_id in
    String.concat " " (ed.editor_command :: ed.editor_options)
  with Not_found ->
    Why3.Whyconf.(default_editor (get_main config))

let scriptfile ~force ~ext wpo =
  let dir = Wp_parameters.Session.get_dir ~create_path:force "interactive" in
  Filepath.(dir / (wpo.Wpo.po_sid ^ ext))

let updatescript ~script driver task =
  let backup = Filepath.extend script ".bak" in
  Filesystem.rename script backup ;
  let _printing_info =
    let open Filesystem.Operators in
    let$ old = Filesystem.with_open_in_exn backup in
    let$ fmt = Filesystem.with_formatter_exn script in
    Why3.Driver.print_task_prepared ~old driver fmt task
  in
  if Filesystem.same_digest backup script then Filesystem.remove_file backup

let editor ~script ~merge ~config pconf driver task =
  Task.sync editor_mutex
    begin fun () ->
      Wp_parameters.feedback ~ontty:`Transient "Editing %a..."
        Filepath.pretty script ;
      if merge then updatescript ~script driver task ;
      let command = editor_command pconf in
      Wp_parameters.debug ~dkey "Editor command %S" command ;
      let probes = Probe.Map.empty in
      call_prover_task ~config ~timeout:None ~steps:None ~probes pconf.prover @@
      Why3.Call_provers.call_editor ~command ~config (Filepath.to_string_abs script)
    end

let compile ~script ~timeout ~memlimit ~config pconf driver prover task =
  run_batch ~config pconf driver ~script ~timeout ~memlimit ~steplimit:None
    ~probes:Probe.Map.empty prover task

let prepare ~mode wpo driver task =
  let ext = Filename.extension (Why3.Driver.file_of_task driver "S" "T" task) in
  let force = mode <> Prover.InteractiveMode.Batch in
  let script = scriptfile ~force wpo ~ext in
  if Filesystem.exists script then Some (script, true) else
  if force then
    begin
      let open Filesystem.Operators in
      let$ fmt = Filesystem.with_formatter_exn script in
      ignore @@ Why3.Driver.print_task_prepared driver fmt task;
      Some (script, false)
    end
  else None

let interactive ~mode ~config wpo pconf driver prover task =
  let time = Wp_parameters.InteractiveTimeout.get () in
  let mem = Wp_parameters.Memlimit.get () in
  let timeout = if time <= 0 then None else Some (float time) in
  let memlimit = if mem <= 0 then None else Some mem in
  match prepare ~mode wpo driver task with
  | None ->
    Wp_parameters.warning ~once:true ~current:false
      "Missing script(s) for prover %a.@\n\
       Use -wp-interactive=fix for interactive proving."
      Why3.Whyconf.print_prover prover ;
    Task.return VCS.unknown
  | Some (script, merge) ->
    Wp_parameters.debug ~dkey "%s %a script %S@."
      (if merge then "Found" else "New")
      Why3.Whyconf.print_prover prover (Filepath.to_string_abs script) ;
    match mode with
    | Prover.InteractiveMode.Batch ->
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
    | Update ->
      if merge then updatescript ~script driver task ;
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
    | Edit ->
      let open Task in
      editor ~script ~merge ~config pconf driver task >>= fun _ ->
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
    | Fix ->
      let open Task in
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
      >>= fun r ->
      if VCS.is_valid r then return r else
        editor ~script ~merge ~config pconf driver task >>= fun _ ->
        compile ~script ~timeout ~memlimit ~config pconf driver prover task
    | FixUpdate ->
      let open Task in
      if merge then updatescript ~script driver task ;
      compile ~script ~timeout ~memlimit ~config pconf driver prover task
      >>= fun r ->
      if VCS.is_valid r then return r else
        let merge = false in
        editor ~script ~merge ~config pconf driver task >>= fun _ ->
        compile ~script ~timeout ~memlimit ~config pconf driver prover task

let automated ~config ~probes ~timeout ~steplimit ~memlimit
    wpo pconf drv prover task =
  if Wp_parameters.Output.exists () then output_task wpo drv prover task;
  if Probe.Map.is_empty probes then
    Cache.get_result
      ~digest:(digest_task wpo drv)
      ~runner:(run_batch ~config ~probes ~memlimit pconf drv ?script:None)
      ~timeout ~steplimit prover task
  else
    run_batch ~config ~probes ~memlimit ~timeout ~steplimit
      pconf drv prover task

(* -------------------------------------------------------------------------- *)
(* --- Prove WPO                                                          --- *)
(* -------------------------------------------------------------------------- *)

let is_trivial (t : Why3.Task.task) =
  let goal = Why3.Task.task_goal_fmla t in
  Why3.Term.t_equal goal Why3.Term.t_true

let print_debug_task wpo drv prover task =
  let pp_task fmt task =
    ignore @@ Why3.Driver.print_task_prepared drv fmt task in
  if Wp_parameters.Output.exists () then
    let out_dir =
      Wp_parameters.Output.get_dir (WpContext.MODEL.id wpo.Wpo.po_model) in
    let prover = Why3Env.title prover in
    let goal = Wpo.get_gid wpo ^ "_" ^ prover in
    let filename = Why3.Driver.file_of_task drv "" goal task in
    let file = Filepath.(out_dir / filename) in
    let out_channel = open_out (Filepath.to_string_abs file) in
    let fmt = Format.formatter_of_out_channel out_channel in
    Format.fprintf fmt "%a" pp_task task ;
    close_out out_channel
  else
    Wp_parameters.feedback "%a" pp_task task

let build_proof_task ?(mode=Prover.InteractiveMode.Batch) ?timeout ?steplimit ?memlimit
    ~prover wpo () =
  try
    (* Always generate common task *)
    let context = Wpo.get_context wpo in
    let ce,prover =
      if Wp_parameters.CounterExamples.get () then
        match Why3Env.with_counter_examples prover with
        | Some prover_ce -> true,prover_ce
        | None -> false,prover
      else false, prover in
    let task,probes = WpContext.on_context context (task_of_wpo ~ce) wpo in
    if Wp_parameters.Generate.get ()
    then Task.return VCS.no_result (* Only generate *)
    else
      let env = Why3Env.env () in
      let config = Why3.Whyconf.get_main @@ Why3Env.config () in
      let drv , pconf , task = prover_task env prover task in
      if Wp_parameters.is_debug_key_enabled dkey_pp_task then
        print_debug_task wpo drv prover task ;
      if is_trivial task then
        Task.return VCS.valid
      else
      if pconf.interactive then
        interactive ~mode ~config wpo pconf drv prover task
      else
        automated ~config ~probes ~timeout ~steplimit ~memlimit
          wpo pconf drv prover task
  with
  | Log.AbortError _ ->
    Task.failed "[User Error]"
  | Log.AbortFatal _ ->
    Task.failed "[Compilation Error]"
  | exn ->
    if Wp_parameters.has_dkey dkey then
      Wp_parameters.fatal "[Why3 Error] %a@\n%s"
        Why3.Exn_printer.exn_printer exn
        Printexc.(raw_backtrace_to_string @@ get_raw_backtrace ())
    else
      Task.failed "[Why3 Error] %a" Why3.Exn_printer.exn_printer exn

let prove ?mode ?timeout ?steplimit ?memlimit ~prover wpo =
  Task.later
    (build_proof_task ?mode ?timeout ?steplimit ?memlimit ~prover wpo) ()

(* -------------------------------------------------------------------------- *)
