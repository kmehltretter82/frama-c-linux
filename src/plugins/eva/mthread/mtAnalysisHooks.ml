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

open Eva_ast
open MtLib
open MtCil
open MtMemory.Types
open MtTypes
open MtSharedVarsTypes
open MtThread

let wrap_res res = Some (MtMemory.int_to_value res)
let no_res = (None : value option)

type hook_sig = (exp * value) list ->  state * value option

let current_loc analysis =
  match Callstack.top_callsite analysis.curr_stack with
  | Kglobal -> assert false (* The current stack must contain the call to the builting creating the thread *)
  | Kstmt stmt ->
    stmt, Option.get (Callstack.pop analysis.curr_stack)

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
    else Option.value (Callstack.pop stack) ~default:stack
  in
  let ki = Callstack.top_callsite stack in
  let source = kinstr_to_source ki in
  let pp_callstack =
    MtOptions.PrintCallstacks.get () || MtOptions.debug_level () > 1 in
  let append = (fun fmt -> if pp_callstack then
                   Format.fprintf fmt "@.%a" Callstack.pretty stack)
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

let find_failure kind id =
  let pp fmt =
    Format.fprintf fmt
      "Id %d for %s does not exists@ (incrementation@ inside@ program?)."
      id kind
  in
  `Failure pp

let find_thread id =
  match Thread.find id with
  | Some th -> `Success th
  | None -> find_failure "thread" id

let find_mutex id =
  match Mutex.find id with
  | Some m -> `Success m
  | None -> find_failure "mutex" id

let find_queue id =
  match Mqueue.find id with
  | Some q -> `Success q
  | None -> find_failure "queue" id


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
let check_id_content default_msg msg_int id state =
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
  Mutex.Set.fold
    (fun mutex state -> MtIds.replace_id_value state (MtIds.of_mutex mutex) ~before:2 ~after:1)
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


let check_thread_not_already_started warn th state =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "Unable to determine that thread %a@ has not already been started.@ \
           %a should be 0@." Thread.pretty th pp v;
    }
    (function
      | 2 -> ()
      | 0 ->
        warn.ppp "Thread %a@ might not be created yet@." Thread.pretty th;
      | 1 ->
        warn.ppp "Thread %a@ might have already been started@ by the \
                  current thread.@." Thread.pretty th;
      | 3 ->
        warn.ppp "Thread %a@ might have been cancelled @ by the \
                  current thread.@." Thread.pretty th;
      | _ -> raise Not_found)
    (MtIds.of_thread th) state

let check_thread_not_already_suspended warn th state =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "Unable to determine that thread %a@ has not already been suspended.@ \
           %a should be 0@." Thread.pretty th pp v;
    }
    (function
      | 1 -> ()
      | 0 ->
        warn.ppp "Thread %a@ might not be created yet@." Thread.pretty th;
      | 2 ->
        warn.ppp "Thread %a@ might have already been suspended@ by the \
                  current thread.@." Thread.pretty th;
      | 3 ->
        warn.ppp "Thread %a@ might have been cancelled @ by the \
                  current thread.@." Thread.pretty th;
      | _ -> raise Not_found)
    (MtIds.of_thread th) state

let check_thread_not_already_cancelled warn th state =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "Unable to determine that thread %a@ has not already been cancelled.@ \
           %a should be 0@." Thread.pretty th pp v;
    }
    (function
      | 1 | 2 -> ()
      | 0 ->
        warn.ppp "Thread %a@ might not be created yet@." Thread.pretty th;
      | 3 ->
        warn.ppp "Thread %a@ might have been already cancelled @ by the \
                  current thread.@." Thread.pretty th;
      | _ -> raise Not_found)
    (MtIds.of_thread th) state



let check_mutex_not_already_initialized warn m state =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that mutex %a@ has not been already \
           initialized;@ %a should be 0@]@." Mutex.pretty m pp v }
    (function
      | 0 -> ()
      | 1 -> warn.ppp "@[<hov>Mutex %a@ might be already initialized@]@."
               Mutex.pretty m
      | 2 -> warn.ppp "@[<hov>Mutex %a@ might be already initialized \
                       (and locked)@]@." Mutex.pretty m
      | _ -> raise Not_found)
    (MtIds.of_mutex m) state

let check_mutex_not_already_locked warn m state =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that mutex %a@ has not already been locked;@ \
           %a should be 1@]@." Mutex.pretty m pp v }
    (function
      | 1 -> ()
      | 0 -> warn.ppp "@[<hov>Mutex %a@ might have not been initialized@]@."
               Mutex.pretty m
      | 2 -> warn.ppp "@[<hov>Mutex %a@ might have already been locked@]@."
               Mutex.pretty m
      | _ -> raise Not_found)
    (MtIds.of_mutex m) state

let check_mutex_locked warn m state =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that mutex %a@ has already been locked;@ \
           %a should be 2@]@." Mutex.pretty m pp v }
    (function
      | 2 -> ()
      | 0 -> warn.ppp "@[<hov>Mutex %a@ might be uninitialized@]@."
               Mutex.pretty m
      | 1 -> warn.ppp "@[<hov>Mutex %a@ might not be locked@]@."
               Mutex.pretty m
      | _ -> raise Not_found)
    (MtIds.of_mutex m) state

let check_queue_not_already_initialized warn q state =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that queue %a@ has not been already \
           initialized;@ %a should be 0@]@." Mqueue.pretty q pp v }
    (function
      | 0 -> ()
      | 1 -> warn.ppp "@[<hov>Queue %a@ might be@ already@ initialized@]@."
               Mqueue.pretty q       | _ -> raise Not_found)
    (MtIds.of_queue q) state

let check_queue_already_initialized warn q state =
  check_id_content
    { pf = fun pp v -> warn.ppp
          "@[<hov>Unable to check that queue %a@ is@ already \
           initialized;@ %a should be 0@]@." Mqueue.pretty q pp v }
    (function
      | 1 -> ()
      | 0 -> warn.ppp "@[<hov>Queue %a@ might be@ uninitialized@]@."
               Mqueue.pretty q
      | _ -> raise Not_found)
    (MtIds.of_queue q) state

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
  let value = Results.(in_cvalue_state state |> eval_var v |> as_cvalue) in
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
           if not (ThreadState.equal analysis.curr_thread th) then
             join ~written ~state
           else state
      )


let hook_sync analysis state : hook_sig = function _ ->
  sync_values analysis state, no_res

(* -------------------------------------------------------------------------- *)
(* --- Creation of a thread                                               --- *)
(* -------------------------------------------------------------------------- *)

let basic_thread eva_thread stack func state params parent = {
  th_eva_thread = eva_thread;
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

let spawn_thread analysis eva_thread stack func state params parent =
  try
    let th' = Thread.Hashtbl.find analysis.all_threads eva_thread in

    if Option.equal ThreadState.equal parent th'.th_parent = false
    then (
      let pp_parent = Pretty_utils.pp_opt ~none:"<none>" ThreadState.pretty in
      log ~kind:Log.Error analysis "Thread '%a' is launched@ by two different \
                                    threads@ (%a and %a).@ Ignoring"
        Thread.pretty eva_thread
        pp_parent parent
        pp_parent th'.th_parent;
      hook_fail ())

    else if Callstack.equal stack th'.th_stack = false then (
      log ~kind:Log.Error analysis
        "Thread '%a' is launched in two different contexts:@.\
         Context 1:@.@[<hov 2>  %a@]@.Context 2:@.@[<hov 2>  %a@]@.Ignoring"
        Thread.pretty eva_thread
        Callstack.pretty stack
        Callstack.pretty th'.th_stack;
      hook_fail ())

    else if Kernel_function.get_id func <> Kernel_function.get_id th'.th_fun
    then (
      log ~kind:Log.Error analysis
        "Thread '%a' can be two different functions@ \
         (%s and %s).@ Imprecise pointer?@ Ignoring."
        Thread.pretty eva_thread
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
      if ris then ThreadState.recompute_because th' InitialEnvChanged;
      if ra  then ThreadState.recompute_because th' InitialArgsChanged;
      let text =
        if ris || ra then "New context for" else "Thread" in
      log ~kind:Log.Result analysis "@[<hov 2>%s@ %a@]" text ThreadState.pretty_detailed th';
      th'
    )
  with Not_found ->
    let th = basic_thread eva_thread stack func state params parent in
    th.th_to_recompute <- SetRecomputeReason.singleton FirstIteration;
    Thread.Hashtbl.add analysis.all_threads eva_thread th;
    log ~kind:Log.Result analysis "@[<hov>New thread: %a@]" ThreadState.pretty_detailed th;
    th



let main_thread k_main initial_state =
  match k_main.Cil_types.fundec with
  | Declaration (_,f,_,_) ->  MtOptions.fatal
                                "Entry point '%s' has no definition : cannot run main." f.vname
  | Definition (f_main,_) ->
    let formals = f_main.sformals in
    let eval_arg vi =
      Results.(in_cvalue_state initial_state |> eval_var vi |> as_cvalue)
    in
    let args = List.map eval_arg formals in
    let stack = Callstack.init k_main in
    basic_thread Thread.main stack k_main initial_state args None


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
    let kf = conv (MtMemory.extract_fun f)
        ~msg:"invalid@ thread@ function" () in
    let formals = Kernel_function.get_formals kf in
    let rec trunc_params = function
      | [], [] -> []
      | _formal :: qf, param :: qp -> param :: trunc_params (qf, qp)
      | [], (_ :: _ as params) ->
        if MtOptions.ModerateWarnings.get () then
          log ~kind:Log.Warning analysis
            "@[During thread@ creation,@ mismatch@ between@ function \
             '%s'@ signature and@ actual arguments.@ Ignoring@ last \
             %d argument(s)@ and@ continuing.@]"
            (Kernel_function.get_name kf) (List.length params);
        []
      | _ :: _, [] ->
        log ~kind:Log.Error analysis
          "@[When creating@ thread@ from@ function %s:@ too@ few@ \
           arguments,@ %d expected@ but@ %d given.@ Ignoring.@]"
          (Kernel_function.get_name kf)
          (List.length formals) (List.length params);
        hook_fail ()
    in
    let params = List.map snd (trunc_params (formals, params)) in
    let eva_thread =
      let name = Concurency.Name.of_cvalue name in
      let aloc = current_loc analysis in
      Thread.spawn aloc name [kf] params |> List.hd
    in
    ignore (spawn_thread analysis eva_thread analysis.curr_stack kf
              Cvalue.Model.bottom params (Some analysis.curr_thread));
    register_event analysis (CreateThread eva_thread);
    (* Thread is started as suspended *)
    MtIds.write_id_state state (MtIds.of_thread eva_thread) 2,
    wrap_res (Thread.id eva_thread)

  | _ -> MtOptions.fatal "Incorrect mthread binding for thread creation"
(* By typing, __FRAMAC_THREAD_CREATE must receive at least those
   arguments *)


let update_initial_state analysis th state =
  (* From now on, at least two threads are running *)
  let state = thread_is_running state in
  (* Remove references local to the parent thread *)
  let state_started = MtMemory.clear_non_globals state in
  (* Mutexes should be unlocked in the new threads *)
  let state_started = reset_mutexes analysis.all_mutexes state_started in
  let th =  Thread.Hashtbl.find analysis.all_threads th in
  let initial, changed = MtMemory.join_state th.th_init_state state_started in
  if changed then (
    ThreadState.recompute_because th MtThread.InitialEnvChanged;
    if Cvalue.Model.is_reachable th.th_init_state then
      log ~kind:Log.Result analysis "@[<hov 2>New context for@ %a@]"
        ThreadState.pretty th;
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
      let th = conv (find_thread offset)
          ~msg:"unkonwn@ thread" () in
      (check (log_poly ~kind:Log.Warning analysis) th state : unit);
      let evt = evt th in
      log ~kind:Log.Result analysis "@[%a@]" Event.pretty evt;
      register_event analysis evt;
      let state_started = aux_state analysis th (state:state) in
      MtIds.write_id_state state_started (MtIds.of_thread th) v, wrap_res 0
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
      let th = conv (find_thread offset)
          ~msg:"unkonwn@ thread" () in
      check_thread_not_already_cancelled
        (log_poly ~kind:Log.Warning analysis) th state;
      register_event analysis (CancelThread th);
      MtIds.write_id_state state (MtIds.of_thread th) 2, wrap_res 0
    else (
      log ~kind:Log.Warning analysis
        "Trying to@ cancel@ unknown thread.@ Ignoring.";
      hook_fail ~code:(-1) ())

  | _ -> MtOptions.fatal "Incorrect mthread binding for thread cancellation \
                          (only the thread id is expected)"

let hook_thread_exit analysis (_state: state) : hook_sig = function
  | [_, v]  ->
    if ThreadState.is_main analysis.curr_thread then (
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
  state, wrap_res (Thread.id analysis.curr_thread.th_eva_thread)


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
            log ~kind:Log.Warning analysis
              "Conflicting priorities (previous: %d, new %d) for thread '%a'."
              p
              p'
              ThreadState.pretty analysis.curr_thread;
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
    let conv v =
      catch_conversion analysis "During@ queue@ initialization" v
    in
    let aloc = current_loc analysis
    and name = Concurency.Name.of_cvalue name
    and size = conv (MtMemory.extract_int size) ~msg:"invalid@ size" () in
    let q = Mqueue.create aloc name in
    analysis.all_queues <- Mqueue.Set.add q analysis.all_queues;
    check_queue_not_already_initialized
      (log_poly ~kind:Log.Warning analysis) q state;
    let size = if size < 0 then None else Some size in
    register_event analysis (CreateQueue (q, size));
    MtIds.write_id_state state (MtIds.of_queue q) 1,
    wrap_res (Mqueue.id q)

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
      let q = conv (find_queue offset) () in
      let content = MtMemory.read_slice ~p:content ~sbytes state in
      check_queue_already_initialized
        (log_poly ~kind:Log.Warning analysis) q state;
      let action = SendMsg (q, (content, sbytes)) in
      log ~kind:Log.Result analysis "@[%a@]" Event.pretty action;
      register_event analysis action;
      state, wrap_res 0
    else (
      log ~kind:Log.Warning analysis
        "@[<hov>Trying to@ send@ message@ on@ uninitialized@ queue.@ \
         Ignoring@]";
      state, wrap_res (-1))

  | _ -> MtOptions.fatal "Incorrect mthread binding for message sending"


let find_msg_content analysis q =
  let extract_action th acc = function
    | SendMsg (q', (v, size)) ->
      if Mqueue.equal q q' then (th, v, size) :: acc else acc
    | _ -> acc
  in
  fold_threads analysis []
    (fun { th_eva_thread = th; th_amap = m } ->
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
      let q = conv (find_queue offset) () in
      check_queue_already_initialized
        (log_poly ~kind:Log.Warning analysis) q state;
      let action = ReceiveMsg (q, p, smax) in
      register_event analysis action;
      let contents = find_msg_content analysis q in
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
                        Thread.pretty th
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
      let m = conv (find_mutex offset) () in
      f_check (log_poly ~kind:Log.Warning analysis) m state;
      let evt : event = event m in
      log ~kind:Log.Result analysis "%a" Event.pretty evt;
      register_event analysis evt;
      let state_op = MtIds.write_id_state state (MtIds.of_mutex m) value in
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
    let aloc = current_loc analysis
    and name = Concurency.Name.of_cvalue name in
    let mutex = Mutex.create aloc name in
    analysis.all_mutexes <- Mutex.Set.add mutex analysis.all_mutexes;
    check_mutex_not_already_initialized
      (log_poly ~kind:Log.Warning analysis) mutex state;
    log ~kind:Log.Result analysis "Initializing mutex %a" Mutex.pretty mutex;
    MtIds.write_id_state state (MtIds.of_mutex mutex) 1,
    wrap_res (Mutex.id mutex)

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


(* -------------------------------------------------------------------------- *)
(** --- Main declarations                                                 --- *)
(* -------------------------------------------------------------------------- *)

(* All the Mthread builtin functions, together with their C name.
   The remainder of the conversion to the real type of the callback
   {Builtins.register_builtin} occurs in [MtMain] *)
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
     match Callstack.pop analysis.curr_stack with
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
      let th = spawn_thread analysis th.th_eva_thread
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

(* Function registered by [Cvalue_callbacks.register_call_results_hook].
   Given the end states of a function with a definition, records the variable
   accesses it did. *)
let catch_functions_record analysis stack _kf _pre_state = function
  | `Body (Cvalue_callbacks.{before_stmts; after_stmts}, i) ->
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
