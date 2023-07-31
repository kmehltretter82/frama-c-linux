(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

open Eva.Eva_ast
open MtLib
open MtCil
open MtMemory.Types
open MtIds
open MtTypes
open MtSharedVarsTypes
open MtThread

let wrap_res res = Some (MtMemory.int_to_value res)
let no_res = (None : value option)

type hook_sig = (exp * value) list ->  state * value option


(* -------------------------------------------------------------------------- *)
(* --- Specialized logging functions                                      --- *)
(* -------------------------------------------------------------------------- *)
(* To be used only inside hooks, as it makes pretty bold assumptions on
   the shape of the stack *)

let log_poly ?(pop_stack=true) ?(kind=Log.Result) analysis =
  let stack = analysis.curr_stack in
  let stack =
    if not pop_stack || MtOptions.PopTopFunctionForCallbacks.get ()
    then stack
    else Option.value (Eva.Callstack.pop stack) ~default:stack
  in
  let ki = Eva.Callstack.top_callsite stack in
  let source = kinstr_to_source ki in
  let pp_callstack =
    MtOptions.PrintCallstacks.get () || MtOptions.debug_level () > 1 in
  let append = (fun fmt -> if pp_callstack then
                   Format.fprintf fmt "@.%a" Eva.Callstack.pretty stack)
  in { ppp = fun fmt ->
      MtOptions.MThread.log ~kind ~once:true ?source ~append
        ("@[" ^^ fmt ^^ "@]")
    }

let log ?(pop_stack=true) ?(kind=Log.Result) analysis =
  (log_poly ~pop_stack ~kind analysis).ppp

exception Hook_failure of int
let default_err_code = -255
let hook_fail ?(code=default_err_code) () =
  raise (Hook_failure code)

(* Auxiliary function that aborts a hook when a conversion of something
   into a proper value fails *)
let catch_conversion analysis msg_main v ?(pop_stack=true) ?(code=default_err_code) ?msg () =
  let warn fm msg_end =
    let msg = match msg with
      | Some msg -> ":@ " ^^ msg
      | None -> ""
    in
    log ~kind:Log.Warning analysis ~pop_stack "@[%(%)%(%).@ %t%(%)@]"
      msg_main msg fm msg_end;
  in
  match v with
  | `Success v -> v
  | `WithWarning (w, v) ->
    warn w "";
    v
  | `Failure w ->
    warn w "@ Ignoring.";
    hook_fail ~code ()

(* -------------------------------------------------------------------------- *)
(* --- Specialization of id function                                          *)
(* -------------------------------------------------------------------------- *)

let register_id analysis conv idt p =
  let v =
    MtIds.register_new_id analysis.known_ids idt p analysis.curr_stack
      analysis.curr_thread.th_id analysis.iteration
  in
  let id, known = conv v () in
  analysis.known_ids <- known;
  id

let find_id analysis = MtIds.find_id analysis.known_ids

let give_name_to_id analysis conv id name =
  let v = MtIds.give_name_to_id analysis.known_ids id name in
  let r, known = conv v () in
  analysis.known_ids <- known;
  r

(* -------------------------------------------------------------------------- *)
(* --- Constants written in memory to store states                        --- *)
(* -------------------------------------------------------------------------- *)
(* Currently not used, because we would need them inside pattern-matching *)

let _s_thread_unknown = 0
let _s_thread_started = 1
let _s_thread_cancelled = 2

let _s_mutex_not_init = 0
let _s_mutex_init = 1
let _s_mutex_locked = 2

let _queue_not_init = 0
let _queue_init = 1


(* -------------------------------------------------------------------------- *)
(* --- Basic, per-thread, checking                                        --- *)
(* -------------------------------------------------------------------------- *)

(* This section is used to check the consistency of the information we store
   into the ids of threads, mutexes, etc. *)

(* Auxiliary function which extracts the information into the id and
   call dispatch functions, or return errors when the information is
   not of the proper form *)
let check_id_content default_msg msg_int (id, state) =
  let pb pp v = default_msg.pf pp v in
  let value = MtIds.read_id_state state id in
  match Locations.Location_Bytes.fold_i (fun b i l -> (b,i) :: l) value [] with
  | [Base.Null,i]  ->
    (try
       let r = Abstract_interp.Int.to_int_exn (Ival.project_int i) in
       try msg_int r
       with Not_found -> pb Format.pp_print_int r

     with Ival.Not_Singleton_Int -> pb Ival.pretty i
    )

  | _ -> pb Cvalue.V.pretty value



(** When a thread is created, it must not inherit from its creator the status
    of mutexes. This function sets all mutexes passed as argument to 1
    (unlocked). *)
let reset_mutexes mutexes state =
  Id.Set.fold
    (fun mutex state -> MtIds.replace_id_value state mutex ~before:2 ~after:1)
    mutexes state

let _mutex_state fmt = function
  | 0 -> Format.fprintf fmt "not initialized"
  | 1 -> Format.fprintf fmt "unlocked"
  | 2 -> Format.fprintf fmt "locked"
  | k -> Format.fprintf fmt "in an@ unknown@ state (%d)" k

let _thread_state fmt = function
  | 0 -> Format.fprintf fmt "not created"
  | 1 -> Format.fprintf fmt "started"
  | 2 -> Format.fprintf fmt "suspended"
  | 3 -> Format.fprintf fmt "cancelled"
  | k -> Format.fprintf fmt "in an@ unknown@ state (%d)" k


(** This function checks that the thread we are supposed to create has
    not already been started in the current thread. *)
let check_thread_not_already_created id log exn =
  check_id_content
    { pf = fun pp v -> log.ppp
          "Unable to determine that thread %a@ has not already been created.@ \
           %a should be 0@." Id.pretty id pp v;
        raise exn
    }
    (function
      | 0 -> ()
      | _ ->
        log.ppp "Thread %a@ might have been created previously@ in the \
                 current thread.@." Id.pretty id;
        raise exn
    )

let check_thread_not_already_started warn id =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "Unable to determine that thread %a@ has not already been started.@ \
           %a should be 0@." Id.pretty id pp v;
    }
    (function
      | 2 -> ()
      | 0 ->
        warn.ppp "Thread %a@ might not be created yet@." Id.pretty id;
      | 1 ->
        warn.ppp "Thread %a@ might have already been started@ by the \
                  current thread.@." Id.pretty id;
      | 3 ->
        warn.ppp "Thread %a@ might have been cancelled @ by the \
                  current thread.@." Id.pretty id;
      | _ -> raise Not_found)

let check_thread_not_already_suspended warn id =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "Unable to determine that thread %a@ has not already been suspended.@ \
           %a should be 0@." Id.pretty id pp v;
    }
    (function
      | 1 -> ()
      | 0 ->
        warn.ppp "Thread %a@ might not be created yet@." Id.pretty id;
      | 2 ->
        warn.ppp "Thread %a@ might have already been suspended@ by the \
                  current thread.@." Id.pretty id;
      | 3 ->
        warn.ppp "Thread %a@ might have been cancelled @ by the \
                  current thread.@." Id.pretty id;
      | _ -> raise Not_found)

let check_thread_not_already_cancelled warn id =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "Unable to determine that thread %a@ has not already been cancelled.@ \
           %a should be 0@." Id.pretty id pp v;
    }
    (function
      | 1 | 2 -> ()
      | 0 ->
        warn.ppp "Thread %a@ might not be created yet@." Id.pretty id;
      | 3 ->
        warn.ppp "Thread %a@ might have been already cancelled @ by the \
                  current thread.@." Id.pretty id;
      | _ -> raise Not_found)



let check_mutex_not_already_initialized warn id =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that mutex %a@ has not been already \
           initialized;@ %a should be 0@]@." Id.pretty id pp v }
    (function
      | 0 -> ()
      | 1 -> warn.ppp "@[<hov>Mutex %a@ might be already initialized@]@."
               Id.pretty id
      | 2 -> warn.ppp "@[<hov>Mutex %a@ might be already initialized \
                       (and locked)@]@." Id.pretty id
      | _ -> raise Not_found)

let check_mutex_not_already_locked _analysis warn id =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that mutex %a@ has not already been locked;@ \
           %a should be 1@]@." Id.pretty id pp v }
    (function
      | 1 -> ()
      | 0 -> warn.ppp "@[<hov>Mutex %a@ might have not been initialized@]@."
               Id.pretty id
      | 2 -> warn.ppp "@[<hov>Mutex %a@ might have already been locked@]@."
               Id.pretty id
      | _ -> raise Not_found)

let check_mutex_locked _analysis warn id =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that mutex %a@ has already been locked;@ \
           %a should be 2@]@." Id.pretty id pp v }
    (function
      | 2 -> ()
      | 0 -> warn.ppp "@[<hov>Mutex %a@ might be uninitialized@]@."
               Id.pretty id
      | 1 -> warn.ppp "@[<hov>Mutex %a@ might not be locked@]@."
               Id.pretty id
      | _ -> raise Not_found)


let check_queue_not_already_initialized warn id =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that queue %a@ has not been already \
           initialized;@ %a should be 0@]@." Id.pretty id pp v }
    (function
      | 0 -> ()
      | 1 -> warn.ppp "@[<hov>Queue %a@ might be@ already@ initialized@]@."
               Id.pretty id
      | _ -> raise Not_found)

let check_queue_already_initialized warn id =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that queue %a@ is@ already \
           initialized;@ %a should be 0@]@." Id.pretty id pp v }
    (function
      | 1 -> ()
      | 0 -> warn.ppp "@[<hov>Queue %a@ might be@ uninitialized@]@."
               Id.pretty id
      | _ -> raise Not_found)

(* -------------------------------------------------------------------------- *)
(* --- External values for shared zones                                   --- *)
(* -------------------------------------------------------------------------- *)

(* XXX: we should sync values only for the threads that may be alive at this
   point *)
let sync_values analysis state =
  let join ~written ~state =
    Cvalue.Model.fold
      (fun b offsm state ->
         let offsm' = Cvalue.Model.find_base_or_default b state in
         match offsm' with
         | `Top -> MtOptions.fatal "Top state"
         | `Bottom -> state
         | `Value offsm' ->
           let offsm'' = Cvalue.V_Offsetmap.join offsm offsm' in
           Cvalue.Model.add_base b offsm'' state)
      written state
  in
  let v = MtSharedVars.var_thread_created () in
  let value = Eva.Results.(in_cvalue_state state |> eval_var v |> as_cvalue) in
  match MtMemory.extract_int value with
  | `Success 0 ->
    (* As no thread is running, just skip the synchronization. *)
    state
  | _ ->
    fold_threads analysis state
      (fun th state ->
         match th.th_values_written with
         | Cvalue.Model.Bottom -> state
         | Cvalue.Model.Top -> Cvalue.Model.top
         | Cvalue.Model.Map written ->
           if not (Thread.equal analysis.curr_thread th) then
             join ~written ~state
           else state
      )


let hook_sync analysis state : hook_sig = function _ ->
  sync_values analysis state, no_res

(* -------------------------------------------------------------------------- *)
(* --- Creation of a thread                                               --- *)
(* -------------------------------------------------------------------------- *)

let basic_thread id stack func state params parent = {
  th_id = id;
  th_stack = stack;
  th_init_state = state;
  th_fun = func;
  th_params = params;
  th_parent = parent;
  th_to_recompute = SetRecomputeReason.empty;
  th_read_written = AccessesByZone.empty_map;
  th_amap = Trace.empty;
  th_cfg = MtCfgTypes.CfgNode.dead;
  th_read_written_cfg = MtCfgTypes.AccessesByZoneNode.empty_map;
  th_values_written = Cvalue.Model.empty_map;
  th_projects = [];
  th_value_results = None;
  th_priority= PDefault;
}

let spawn_thread analysis id stack func state params parent =
  try
    let th' = Id.Hashtbl.find analysis.all_threads id in

    if Option.equal (fun th th' -> Id.equal th.th_id th'.th_id)
        parent th'.th_parent = false
    then (
      log ~kind:Log.Error analysis "Thread '%a' is launched@ by two different \
                                    threads@ (%a and %a).@ Ignoring"
        Id.pretty id
        Thread.pretty_parent_id parent Thread.pretty_parent_id th'.th_parent;
      hook_fail ())

    else if Eva.Callstack.equal stack th'.th_stack = false then (
      log ~kind:Log.Error analysis
        "Thread '%a' is launched in two different contexts:@.\
         Context 1:@.@[<hov 2>  %a@]@.Context 2:@.@[<hov 2>  %a@]@.Ignoring"
        Id.pretty id
        Eva.Callstack.pretty stack
        Eva.Callstack.pretty th'.th_stack;
      hook_fail ())

    else if Kernel_function.get_id func <> Kernel_function.get_id th'.th_fun
    then (
      log ~kind:Log.Error analysis
        "Thread '%a' can be two different functions@ \
         (%s and %s).@ Imprecise pointer?@ Ignoring."
        Id.pretty id
        (Kernel_function.get_name func)
        (Kernel_function.get_name th'.th_fun);
      hook_fail ())

    else (
      (* Fields that are being joined *)
      let init_state', ris = MtMemory.join_state th'.th_init_state state
      and args, ra = MtMemory.join_params th'.th_params params
      in
      th'.th_init_state <- init_state';
      th'.th_params <- args;
      if ris then Thread.recompute_because th' InitialEnvChanged;
      if ra  then Thread.recompute_because th' InitialArgsChanged;
      let text =
        if ris || ra then "New context for" else "Thread" in
      log ~kind:Log.Result analysis "@[<hov 2>%s@ %a@]" text Thread.pretty th';
      th'
    )
  with Not_found ->
    let th = basic_thread id stack func state params parent in
    th.th_to_recompute <- SetRecomputeReason.singleton FirstIteration;
    Id.Hashtbl.add analysis.all_threads id th;
    log ~kind:Log.Result analysis "@[<hov>New thread: %a@]" Thread.pretty th;
    th



let main_thread k_main initial_state =
  match k_main.Cil_types.fundec with
  | Declaration (_,f,_,_) ->  MtOptions.fatal
                                "Entry point '%s' has no definition : cannot run main." f.vname
  | Definition (f_main,_) ->
    let formals = f_main.sformals in
    let eval_arg vi =
      Eva.Results.(in_cvalue_state initial_state |> eval_var vi |> as_cvalue)
    in
    let args = List.map eval_arg formals in
    let stack = Eva.Callstack.init k_main in
    basic_thread id_main_thread stack k_main initial_state args None


(** Set the global variable that indicates that at least one thread is running
    to one *)
let thread_is_running state =
  let p_thread_running = MtSharedVars.var_thread_created (), 0 in
  MtMemory.write_int_pointer p_thread_running 1 state


(** Hook registered in the value analysis for the creation of thread *)
let hook_thread_creation analysis state : hook_sig = function
  | (_, name) :: (_, f) :: params ->
    let conv v = catch_conversion analysis "During@ thread@ creation" v in
    (* We clean the state that will be used by the created thread *)
    let name = conv (MtIds.extract_name_hint name)
        ~msg:"invalid@ thread@ identifier" ()
    and kf = conv (MtMemory.extract_fun f)
        ~msg:"invalid@ thread@ function" () in
    let id = register_id analysis (fun v () -> conv v ()) IdThread name in
    check_thread_not_already_created id (log_poly ~kind:Log.Error analysis)
      (Hook_failure default_err_code) (id, state);
    let formals = Kernel_function.get_formals kf in
    let rec trunc_params = function
      | [], [] -> []
      | _formal :: qf, param :: qp -> param :: trunc_params (qf, qp)
      | [], (_ :: _ as params) ->
        if MtOptions.ModerateWarnings.get () then
          log ~kind:Log.Warning analysis
            "@[During thread %a@ creation,@ mismatch@ between@ function \
             '%s'@ signature and@ actual arguments.@ Ignoring@ last \
             %d argument(s)@ and@ continuing.@]"
            Id.pretty id (Kernel_function.get_name kf) (List.length params);
        []
      | _ :: _, [] ->
        log ~kind:Log.Error analysis
          "@[When creating@ thread %a@ from@ function %s:@ too@ few@ \
           arguments,@ %d expected@ but@ %d given.@ Ignoring.@]"
          Id.pretty id (Kernel_function.get_name kf)
          (List.length formals) (List.length params);
        hook_fail ()
    in
    let params = List.map snd (trunc_params (formals, params)) in
    ignore (spawn_thread analysis id analysis.curr_stack kf
              Cvalue.Model.bottom params (Some analysis.curr_thread));
    register_event analysis (CreateThread id);
    (* Thread is started as suspended *)
    MtIds.write_id_state state id 2, wrap_res (id_offset id)

  | _ -> MtOptions.fatal "Incorrect mthread binding for thread creation"
(* By typing, __FRAMAC_THREAD_CREATE must receive at least those
   arguments *)


let update_initial_state analysis thid state =
  (* From now on, at least two threads are running *)
  let state = thread_is_running state in
  (* Remove references local to the parent thread *)
  let state_started = MtMemory.clear_non_globals state in
  (* Mutexes should be unlocked in the new threads *)
  let state_started = reset_mutexes (mutexes_ids analysis) state_started in
  let th = Id.Hashtbl.find analysis.all_threads thid in
  let initial, changed = MtMemory.join_state th.th_init_state state_started in
  if changed then (
    Thread.recompute_because th MtThread.InitialEnvChanged;
    if Cvalue.Model.is_reachable th.th_init_state then
      log ~kind:Log.Result analysis "@[<hov 2>New context for@ %a@]"
        Thread.pretty th;
  );
  th.th_init_state <- initial;
  (* Update the state of the creator too: more than one thread is running,
     and the values written by the thread just created become visible. *)
  sync_values analysis state

let hook_thread_start_suspend fname check v aux_state evt analysis state : hook_sig = function
  | [_, offset]  ->
    let conv v = catch_conversion analysis ("During@ thread@ " ^^ fname) v in
    let offset = conv (MtMemory.extract_int offset)
        ~msg:"invalid@ thread@ id" () in
    if offset <> 0 then
      let id = conv (find_id analysis (IdThread, offset))
          ~msg:"unkonwn@ thread" () in
      (check (log_poly ~kind:Log.Warning analysis) id (id, state) : unit);
      let evt = evt id in
      log ~kind:Log.Result analysis "@[%a@]" Event.pretty evt;
      register_event analysis evt;
      let state_started = aux_state analysis id (state:state) in
      MtIds.write_id_state state_started id v, wrap_res 0
    else (
      log ~kind:Log.Warning analysis
        "Trying to@ %(%)@ unknown thread.@ Ignoring." fname;
      hook_fail ~code:(-1) ())

  | _ -> MtOptions.fatal "Incorrect mthread binding for thread %(%)" fname

(** Hook registered in the value analysis when a thread is started *)
let hook_thread_start =
  hook_thread_start_suspend
    "start" check_thread_not_already_started 1 update_initial_state
    (fun i -> StartThread i)

let hook_thread_suspend =
  hook_thread_start_suspend
    "suspend" check_thread_not_already_suspended 2 (fun _ _ s -> s)
    (fun i -> SuspendThread i)



let hook_thread_cancellation analysis state : hook_sig = function
  | [_, offset]  ->
    let conv v = catch_conversion analysis "During@ thread@ cancellation" v in
    let offset = conv (MtMemory.extract_int offset)
        ~msg:"invalid@ thread@ id" () in
    if offset <> 0 then
      let id = conv (find_id analysis (IdThread, offset))
          ~msg:"unkonwn@ thread" () in
      check_thread_not_already_cancelled
        (log_poly ~kind:Log.Warning analysis) id (id, state);
      register_event analysis (CancelThread id);
      MtIds.write_id_state state id 2, wrap_res 0
    else (
      log ~kind:Log.Warning analysis
        "Trying to@ cancel@ unknown thread.@ Ignoring.";
      hook_fail ~code:(-1) ())

  | _ -> MtOptions.fatal "Incorrect mthread binding for thread cancellation \
                          (only the thread id is expected)"

let hook_thread_exit analysis (_state: state) : hook_sig = function
  | [_, v]  ->
    if Id.equal analysis.curr_thread.th_id id_main_thread then (
      log ~kind:Log.Error analysis
        "Call@ to@ thread@ exit@ primitive@ inside@ main@ thread. Ignoring";
      hook_fail ())
    else (
      register_event analysis (ThreadExit v);
      log ~kind:Log.Result analysis "Thread@ exiting@ with@ value %a"
        Cvalue.V.pretty v;
      Cvalue.Model.bottom, no_res)

  | _ -> MtOptions.fatal "Incorrect mthread binding for thread exit \
                          (only the return value is expected)"

let hook_thread_id analysis state : hook_sig = fun _ ->
  state, wrap_res (id_offset analysis.curr_thread.th_id)


let hook_thread_priority analysis state : hook_sig = function
  |[ _, p] ->
    begin
      let p = catch_conversion analysis
          "During@ thread@ priority@ definition" (MtMemory.extract_int p)
          ~msg:"invalid@ thread@ id" ()
      in
      begin
        match analysis.curr_thread.th_priority with
        | PPriority p' ->
          if p <> p' then begin
            log ~kind:Log.Warning analysis "Conflicting priorities \
                                            (previous: %d, new %d) for thread '%a'." p p' Id.pretty
              analysis.curr_thread.th_id;
            (* TODO: add an event + add a recompute reason *)
            analysis.curr_thread.th_priority <- PUnknown;
          end
        | PUnknown -> ()
        | PDefault ->
          log analysis "Setting priority to %d" p;
          analysis.curr_thread.th_priority <- PPriority p;
      end;
      state, wrap_res 0
    end
  | _ -> MtOptions.fatal "Incorrect mthread binding for thread priority \
                          (only a non negative integer is expected)"

(* -------------------------------------------------------------------------- *)
(** --- Hook registered in the value analysis related to messages         --- *)
(* -------------------------------------------------------------------------- *)

let hook_queue_init analysis state : hook_sig = function
  | [_, name; _, size] ->
    let conv v = catch_conversion analysis
        "During@ queue@ initialization" v in
    let name = conv (MtIds.extract_name_hint name)
        ~msg:"invalid@ queue@ name" ()
    and size = conv (MtMemory.extract_int size) ~msg:"invalid@ size" () in
    let id = register_id analysis (fun v () -> conv v ()) IdQueue name in
    check_queue_not_already_initialized
      (log_poly ~kind:Log.Warning analysis) id (id, state);
    let size = if size < 0 then None else Some size in
    register_event analysis (CreateQueue (id, size));
    MtIds.write_id_state state id 1, wrap_res (id_offset id)

  | _ -> MtOptions.fatal "Incorrect mthread binding for queue creation"

let hook_send_msg analysis state : hook_sig = function
  | [(_, offset); (_exp_content, content); (_exp_size, size)] ->
    let conv v = catch_conversion analysis "During@ message@ sending" v in
    let offset = conv (MtMemory.extract_int offset)
        ~msg:"invalid@ queue@ id" () in
    if offset <> 0 then
      let sbytes = conv (MtMemory.extract_int size)
          ~msg:"invalid@ message@ size" () in
      if sbytes <= 0 then
        conv (`Failure (fun fmt -> Format.fprintf fmt
                           "Invalid message length %d." sbytes)) ();
      let id_raw = MtIds.IdQueue, offset in
      let id = conv (find_id analysis id_raw) () in
      let content = MtMemory.read_slice ~p:content ~sbytes state in
      check_queue_already_initialized
        (log_poly ~kind:Log.Warning analysis) id (id, state);
      let action = SendMsg (id, (content, sbytes)) in
      log ~kind:Log.Result analysis "@[%a@]" Event.pretty action;
      register_event analysis action;
      state, wrap_res 0
    else (
      log ~kind:Log.Warning analysis
        "@[<hov>Trying to@ send@ message@ on@ uninitialized@ queue.@ \
         Ignoring@]";
      state, wrap_res (-1))

  | _ -> MtOptions.fatal "Incorrect mthread binding for message sending"


let find_msg_content analysis queue_id =
  let extract_action th acc = function
    | SendMsg (id, (v, size)) ->
      if Id.equal id queue_id then (th, v, size) :: acc else acc
    | _ -> acc
  in
  fold_threads analysis []
    (fun { th_id = th; th_amap = m } ->
       Trace.fold' m (fun a r -> extract_action th r a))

let hook_receive_msg analysis state : hook_sig = function
  | [(_,offset); (_e_size, size); (e_loc, loc)] ->
    let conv v = catch_conversion analysis "During@ message@ reception" v in
    let offset = conv (MtMemory.extract_int offset)
        ~msg:"invalid@ queue@ id" () in
    if offset <> 0 then
      let smax = conv (MtMemory.extract_int size) ~msg:"invalid@ size" ()
      and p = conv (MtMemory.extract_pointer loc)
          ~msg:"invalid@ destination@ buffer" () in
      let id_raw = (MtIds.IdQueue, offset) in
      let id = conv (find_id analysis id_raw) () in
      check_queue_already_initialized
        (log_poly ~kind:Log.Warning analysis) id (id, state);
      let action = ReceiveMsg (id, p, smax) in
      register_event analysis action;
      let contents = find_msg_content analysis id in
      let state, res, pp =
        if contents <> [] then
          let length, kept_mess, _, state =
            List.fold_left
              (fun (length, kept_mess, exact, state) (_, slice, smess as mess) ->
                 let sbytes = min smess smax in
                 let state' =
                   MtMemory.write_slice ~p ~sbytes ~slice ~exact state
                 in
                 if Cvalue.Model.is_reachable state' then
                   let sbytes_val =
                     Cvalue.V.inject_ival (Ival.of_int sbytes) in
                   let length' = Cvalue.V.join sbytes_val length in
                   length', mess :: kept_mess, false, state'
                 else (
                   log ~kind:Log.Warning analysis
                     "Found message@ of length %d,@ which is@ too long@ \
                      for buffer '%a'. Execution@ will@ continue@ without@ \
                      those@ messages.@.(Ignore \"This path is assumed to \
                      be dead message if any\".)"
                     smess pp_exp e_loc;
                   length, kept_mess, exact, state)
              )
              (Cvalue.V.bottom, [], true, state) contents
          in
          match kept_mess with
          | [] ->
            Cvalue.Model.bottom,
            no_res,
            (fun fmt -> Format.fprintf fmt "No valid value@ to receive.")
          | _ :: _ ->
            let pp fmt =
              Format.fprintf fmt "Possible %s values:@.%a"
                (if List.length kept_mess = List.length contents
                 then "" else "valid ")
                (Pretty_utils.pp_list ~pre:"@[<v>" ~sep:"@,"
                   (fun fmt (th, v, _) ->
                      Format.fprintf fmt "@[From thread %a:@ %a@]"
                        Id.pretty th
                        MtMemory.pretty_slice v
                   )) kept_mess
            in
            state, Some length, pp
        else
          Cvalue.Model.bottom,
          no_res,
          (fun fmt -> Format.fprintf fmt "No value@ to receive (yet?).")
      in
      log ~kind:Log.Result analysis "@[<hov>%a@ %t@]"
        Event.pretty action pp;
      state, res
    else (
      log ~kind:Log.Warning analysis
        "Trying@ to@ receive@ value@ on@ non-initialized@ queue. Ignoring.";
      state, wrap_res (-2))

  | _ -> MtOptions.fatal "Incorrect mthread binding for message reception"


(* Auxiliary functions for the functions that act on mutexes (currently
   lock and release). [check] is the function that checks that the state
   of the information stored in the mutex is consistent with the action
   being performed, and the value with which to update the state.
   [evt] returns the corresponding mthread event. *)
let aux_mutex ~operation:op ~check ~event analysis state : hook_sig = function
  | [_, offset] ->
    let f_check, value = check in
    let conv v = catch_conversion analysis ("During@ mutex@ " ^^ op) v in
    let offset, exact = conv (MtMemory.extract_int_possibly_zero offset)
        ~msg:"invalid@ mutex@ id" () in
    if exact = `WithZero then log ~kind:Log.Warning analysis
        "@[<hov>Trying to@ %(%)@ a possibly@ uninitialized@ mutex.@]" op;
    if offset <> 0 then
      let id_raw = (IdMutex, offset) in
      let id = conv (find_id analysis id_raw) () in
      f_check analysis (log_poly ~kind:Log.Warning analysis) id (id, state);
      let evt : event = event id in
      log ~kind:Log.Result analysis "%a" Event.pretty evt;
      register_event analysis evt;
      let state_op = MtIds.write_id_state state id value in
      (* XXX: take which mutex is locked into account, and update only
         those values *)
      let with_external = sync_values analysis state_op in
      with_external, wrap_res  0
    else (
      log ~kind:Log.Warning analysis
        "@[<hov>Trying to@ %(%)@ uninitialized@ mutex.@ Ignoring@]" op;
      state, wrap_res (-1))

  | _ -> (* really unlikely unless the code and/or the C binding
            are really strange *)
    MtOptions.fatal "Incorrect mthread binding for mutex function"

let hook_init_mutex analysis state : hook_sig = function
  | [_, name] ->
    let conv v = catch_conversion analysis
        "During@ mutex@ initialization" v in
    let name = conv (MtIds.extract_name_hint name)
        ~msg:"invalid@ mutex@ name" () in
    let id = register_id analysis (fun v ()-> conv v ()) MtIds.IdMutex name in
    check_mutex_not_already_initialized
      (log_poly ~kind:Log.Warning analysis) id (id, state);
    log ~kind:Log.Result analysis "Initializing mutex %a" Id.pretty id;
    MtIds.write_id_state state id 1, wrap_res (id_offset id)

  | _ -> (* really unlikely unless the code and/or the C binding
            are really strange *)
    MtOptions.fatal "Incorrect mthread binding for mutex function"


let hook_lock_mutex =
  aux_mutex ~operation:"lock" ~check:(check_mutex_not_already_locked, 2)
    ~event:(fun id -> MutexLock id)

let hook_release_mutex =
  aux_mutex ~operation:"unlock" ~check:(check_mutex_locked, 1)
    ~event:(fun id -> MutexRelease id)



(* -------------------------------------------------------------------------- *)
(** --- Misc                                                              --- *)
(* -------------------------------------------------------------------------- *)

let hook_dummy_message analysis state : hook_sig = function
  | (_, name) :: args ->
    let conv v = catch_conversion analysis ~pop_stack:false
        "During@ unknown@ event" v in
    let name = conv (MtMemory.extract_constant_string name)
        ~msg:"invalid@ event@ name" () in
    let evt = Dummy (name, List.map snd args) in
    register_event analysis evt;
    log ~pop_stack:false ~kind:Log.Result analysis
      "Monitored event:@ %a" Event.pretty evt;
    state, no_res

  | _ -> MtOptions.fatal "Incorrect mthread binding for unknown event"


let hook_name_object idt analysis state : hook_sig =
  let format = IdType.format_lc idt in
  function
  | [_, offset; _, name] ->
    let conv v = catch_conversion analysis ~pop_stack:false
        ("During@ " ^^ format ^^ "@ naming") v in
    let name = conv (MtIds.extract_name_hint name)
        ~msg:("Invalid@ " ^^ format ^^ "@ name") () in
    let offset = conv (MtMemory.extract_int offset)
        ~msg:"invalid@ mutex@ id" () in
    if offset <> 0 then
      let id_raw = (idt, offset) in
      let id = conv (find_id analysis id_raw) () in
      let prev_name = id.id_name in
      (match give_name_to_id analysis (fun v () -> conv v ()) id name
       with
       | None -> ()
       | Some name -> log ~kind:Log.Result analysis ~pop_stack:false
                        "%a %s will now be named %s" IdType.pretty idt prev_name name
      );
      state, no_res
    else (
      log ~pop_stack:false ~kind:Log.Warning analysis
        "@[<hov>Trying to@ name@ unknown@ %{%}.@ Ignoring@]" format;
      state, no_res)

  | _ -> MtOptions.fatal "Incorrect mthread binding for %{%} naming" format

(* -------------------------------------------------------------------------- *)
(** --- Main declarations                                                 --- *)
(* -------------------------------------------------------------------------- *)

(* All the Mthread builtin functions, together with their C name.
   The remainder of the conversion to the real type of the callback
   {Eva.Builtins.register_builtin} occurs in [MtMain] *)
let mthread_builtins =
  [
    (* Threads *)
    "__FRAMAC_THREAD_CREATE", hook_thread_creation, `Pop;
    "__FRAMAC_THREAD_START", hook_thread_start, `Pop;
    "__FRAMAC_THREAD_SUSPEND", hook_thread_suspend, `Pop;
    "__FRAMAC_THREAD_CANCEL", hook_thread_cancellation, `Pop;
    "__FRAMAC_THREAD_EXIT", hook_thread_exit, `Pop;
    "__FRAMAC_THREAD_ID", hook_thread_id, `Pop;
    "__FRAMAC_THREAD_PRIORITY", hook_thread_priority, `Pop;
    (* Mutexes *)
    "__FRAMAC_MUTEX_INIT", hook_init_mutex, `Pop;
    "__FRAMAC_MUTEX_LOCK", hook_lock_mutex, `Pop;
    "__FRAMAC_MUTEX_UNLOCK", hook_release_mutex, `Pop;
    (* Message queues *)
    "__FRAMAC_QUEUE_INIT", hook_queue_init, `Pop;
    "__FRAMAC_MESSAGE_SEND", hook_send_msg, `Pop;
    "__FRAMAC_MESSAGE_RECEIVE", hook_receive_msg, `Pop;
    (* Misc *)
    "__FRAMAC_MTHREAD_SHOW", hook_dummy_message, `NoPop;
    "__FRAMAC_MTHREAD_NAME_THREAD", hook_name_object IdThread, `NoPop;
    "__FRAMAC_MTHREAD_NAME_MUTEX",  hook_name_object IdMutex,  `NoPop;
    "__FRAMAC_MTHREAD_NAME_QUEUE",  hook_name_object IdQueue,  `NoPop;
    (* Shared values *)
    "__FRAMAC_MTHREAD_SYNC", hook_sync, `Pop;
  ]
;;

let is_mthread_builtin s =
  try
    let (_, _, pop) = List.find (fun (s', _, _) -> s = s') mthread_builtins in
    pop
  with Not_found -> `NotBuiltin

let mthread_builtins = List.map (fun (n, f, _) -> (n, f)) mthread_builtins

(* Function to register as a callback of the Eva analysis if Mthread
   is enabled *)
let catch_functions_calls analysis stack kf state kind =
  analysis.curr_stack <- stack;
  let f = Kernel_function.get_name kf in
  let built = is_mthread_builtin f in
  (if built <> `NotBuiltin then
     match Eva.Callstack.pop analysis.curr_stack with
     | None -> (* A thread function has been called as main, and we fail
                  immediately. In fact, this case should not happen,
                  because we reject calls to __FRAMA_C_* functions as
                  main or during thread spawning. We could detect when
                  the stack has only one element (ie. pthread_* has
                  been called has main, but the error message arrives
                  too late, and is not really readable *)
       MtOptions.abort "Thread function %s called as starting thread \
                        function" f

     | Some stack ->
       (* For mthread builtin functions, we may remove the top of the stack.
          This way, the mthread events appear at the level of the C
          function, instead of inside a function with a strange name *)
       if MtOptions.PopTopFunctionForCallbacks.get () && built = `Pop then
         analysis.curr_stack <- stack;
  );
  if analysis.curr_stack.stack = [] then begin
    (* Beginning of a thread (kf being the entry point). For the main
       thread, it might have not been registered yet if we are at the
       first iteration. *)
    if analysis.curr_thread.th_parent = None then begin
      let th = main_thread kf state in
      (* This call registers the main thread on the first run, and essentially
         does nothing afterwards *)
      let th = spawn_thread analysis id_main_thread
          th.th_stack th.th_fun th.th_init_state th.th_params None in
      if analysis.main_thread != th then begin
        (* On the first run, the record [th] is created. It is not contained
           anywhere else, so we update the fields below. *)
        analysis.main_thread <- th;
        analysis.curr_thread <- th;
        (* We are currently computing this thread (the main one) and we have
           just started, no need to recompute it at the next iteration *)
        th.th_to_recompute <- SetRecomputeReason.empty;
      end
    end
  end;
  push_function_call analysis;
  (* If the function is a leaf one, we register the accesses that occur
     through \assigns ACSL specifications, then pop the stack. If there is a
     definition, the registering will be done by another hook, at the end of
     the execution of the function *)
  match kind with
  | `Spec | `Builtin ->
    MtSharedVars.register_concurrent_var_accesses analysis (`Leaf state);
    pop_function_call analysis;
  | `Body | `Reuse -> ()

(* Function registered by [Eva.Cvalue_callbacks.register_call_results_hook].
   Given the end states of a function with a definition, records the variable
   accesses it did. *)
let catch_functions_record analysis stack _kf _pre_state = function
  | `Body (Eva.Cvalue_callbacks.{before_stmts; after_stmts}, i) ->
    analysis.curr_stack <- stack;
    let hbefore = Lazy.force before_stmts in
    let hafter = Lazy.force after_stmts in
    MtSharedVars.register_concurrent_var_accesses analysis (`Final hbefore);
    register_memory_states analysis ~before:hbefore ~after:hafter;
    let cur_events = curr_events analysis in
    Datatype.Int.Hashtbl.add analysis.memexec_cache i cur_events;
    pop_function_call analysis;
  | `Reuse i ->
    let events = Datatype.Int.Hashtbl.find analysis.memexec_cache i in
    (* Merge the memoized results in the current analysis *)
    register_multiple_events analysis events;
    pop_function_call analysis;
  | `Builtin _ | `Spec _ -> ()
