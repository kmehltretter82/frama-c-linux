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
open MtIds
open MtTypes
open MtSharedVarsTypes
open MtCfgTypes

(* -------------------------------------------------------------------------- *)
(* --- Threads                                                            --- *)
(* -------------------------------------------------------------------------- *)


type recompute_reason =
  | FirstIteration
  | NewMsgReceived
  | PotentialSharedVarsChanged
  | SharedVarsValuesChanged
  | InitialArgsChanged
  | InitialEnvChanged
;;


module RecomputeReason = struct

  type t = recompute_reason

  let compare r1 r2 = match r1, r2 with
    | FirstIteration, FirstIteration
    | NewMsgReceived, NewMsgReceived
    | SharedVarsValuesChanged, SharedVarsValuesChanged
    | PotentialSharedVarsChanged, PotentialSharedVarsChanged
    | InitialArgsChanged, InitialArgsChanged
    | InitialEnvChanged, InitialEnvChanged
      -> 0
    | (FirstIteration | NewMsgReceived | SharedVarsValuesChanged
      | PotentialSharedVarsChanged | InitialArgsChanged | InitialEnvChanged),
      _ ->
      MtLib.compare_tag r1 r2

  let pretty fmt = function
    | FirstIteration -> Format.fprintf fmt "first@ iteration"
    | NewMsgReceived -> Format.fprintf fmt "new@ message@ received"
    | SharedVarsValuesChanged ->
      Format.fprintf fmt "shared@ vars@ values@ changed"
    | PotentialSharedVarsChanged ->
      Format.fprintf fmt "potential@ shared@ vars@ changed"
    | InitialArgsChanged -> Format.fprintf fmt
                              "thread@ initial@ arguments@ changed"
    | InitialEnvChanged -> Format.fprintf fmt
                             "thread@ initial@ memory@ state@ changed"

end


module SetRecomputeReason = Set.Make(struct
    type t = recompute_reason
    let compare = RecomputeReason.compare
  end)

type priority = PDefault | PUnknown | PPriority of int

module Priority = Datatype.Make_with_collections(struct
    type t = priority
    let name = "MtThread.priority"
    let reprs = [PPriority 0; PDefault; PUnknown]

    include Datatype.Undefined
    let compare: t -> t -> int = Extlib.compare_basic
    let equal = Datatype.from_compare
    let hash = Hashtbl.hash
  end)


type thread = {
  th_id: MtIds.id;
  th_parent : thread option;
  th_fun : kernel_function;
  th_stack : Callstack.t;
  mutable th_init_state : Cvalue.Model.t;
  mutable th_params : Cvalue.V.t list;
  mutable th_amap : Trace.t;
  mutable th_to_recompute: SetRecomputeReason.t;
  mutable th_read_written: AccessesByZone.map;
  mutable th_cfg: CfgNode.t;
  mutable th_read_written_cfg: AccessesByZoneNode.map;
  mutable th_values_written: MtMemory.Types.state;
  mutable th_projects: Project.t list;
  mutable th_value_results: Eva_results.results option;
  mutable th_priority: priority;
}

module Thread = struct
  type t = thread

(*
  open Unmarshal

  let help =
    let l = t_list Locations.Location_Bytes.Datatype.descr in
    let rec descr = Structure (Sum [|
      [| Id.descr;
         Structure (Sum [| [| descr|] |]);
         Kernel_function.Datatype.descr;
         Stack.descr;
         Relations_type.Model.Datatype.descr;
         l;
         Trace.descr;
         t_bool;
         MapVarAccesses.Datatype.descr;
         CfgNode.descr
      |]  |]) in
    descr
*)

  let pretty_parent_id fmt = function
    | None -> Format.fprintf fmt "Main"
    | Some { th_id = id } -> Format.fprintf fmt "%a" Id.pretty id

  let pretty fmt th =
    match th.th_parent with
    | None ->
      Format.fprintf fmt "main,@ fun %s"
        (Kernel_function.get_name th.th_fun)
    | Some p ->
      Format.fprintf fmt "%a,@ fun %s,@ parent %a,@ args %a"
        Id.pretty th.th_id
        (Kernel_function.get_name th.th_fun)
        Id.pretty p.th_id
        (Pretty_utils.pp_list ~sep:",@ " Cvalue.V.pretty) th.th_params


  let equal th1 th2 = Id.equal th1.th_id th2.th_id
  let compare th1 th2 = Id.compare th1.th_id th2.th_id
  let hash th = Id.hash th.th_id


  let one_creates_other th1 th2 =
    let creates thp ths =
      let rec in_parents ths' = match ths'.th_parent with
        | None -> `Unrelated
        | Some th ->
          if Id.equal thp.th_id th.th_id then `Creates (thp, ths)
          else in_parents th
      in
      in_parents ths
    in
    match creates th1 th2 with
    | `Unrelated -> creates th2 th1
    | _ as r -> r


  module Set = Set.Make(struct type t = thread
      let compare = compare
    end)
  module Map = Map.Make(struct type t = thread
      let compare = compare
    end)
  module Hashtbl = Hashtbl.Make(struct type t = thread
      let hash = hash
      let equal = equal
    end)

  let recompute_because th r =
    if not (SetRecomputeReason.equal th.th_to_recompute
              (SetRecomputeReason.singleton FirstIteration))
    (* Can happen if the control-flow leading to the thread creation
       is split by the value analysis *)
    then
      th.th_to_recompute <- SetRecomputeReason.add r th.th_to_recompute
end



(* -------------------------------------------------------------------------- *)
(* --- Thread analysis                                                    --- *)
(* -------------------------------------------------------------------------- *)


type threads_table = thread Id.Hashtbl.t

type analysis_state = {
  all_threads : threads_table (* List of all threads. Is kept (and can thus
                                 increase) from one iteration to the next *);

  mutable iteration: int (* Current iteration of the analysis *);

  mutable main_thread: thread (* Starting thread *);

  mutable curr_thread: thread (* Thread currently running. *);

  mutable curr_events_stack: Trace.t list (* Mthread events that have been
                                             found during the current analysis of the current thread. The list
                                             has the same height as [curr_stack]. The top of the list is the trace
                                             containing the events for the function being analyzed by Value, and
                                             so on until the top of the list. When the list is popped, the events
                                             of the callee are merged inside the trace of the caller. *);

  mutable memexec_cache: Trace.t Datatype.Int.Hashtbl.t
(* Cache for the results obtained during the analysis of the current
   thread *);

  mutable curr_stack: Callstack.t
(* stack of a multithread event. Asynchronously set by a callback and used
   by another, because of a slightly too restricted signature in the
   value analysis. *);

  mutable concurrent_accesses: Locations.Zone.t
(* Shared variables that have been detected in the analysis so far
   in a global manner *);

  mutable precise_concurrent_accesses: Locations.Zone.t
(* Shared variables that have been detected in the analysis so far,
   through the various cfgs. Subset of the previous field *);

  mutable concurrent_accesses_by_nodes:
    (Locations.Zone.t * SetNodeIdAccess.t) list
(* List of concurrent accesses that have been found. Used to
   compute the field [precise_concurrent_accesses] *);

  mutable known_ids: MtIds.known_ids
(* Information on the known threads, mutexes and queues found so
   far *);

}

(* Iterators on threads. We presave the current list of threads so that
   the iterators do not accidentally capture new added threads. (This is not
   important for correctness, but is slightly cleaner.). Threads are sorted,
   agains for cleanliness reasons. *)
let threads analysis =
  let not_main =
    Id.Hashtbl.fold_sorted
      (fun _id th acc ->
         if not (Thread.equal th analysis.main_thread) then th :: acc else acc)
      analysis.all_threads []
  in
  analysis.main_thread :: List.rev not_main

let thread_of_id analysis id =
  try Id.Hashtbl.find analysis.all_threads id
  with Not_found -> MtOptions.fatal "Unknown thread %a" Id.pretty id

let fold_threads analysis v f =
  List.fold_left (fun acc th -> f th acc) v (threads analysis)
let iter_threads analysis f =
  List.iter (fun th -> f th) (threads analysis)

let mutexes_ids analysis = MtIds.all_mutexes analysis.known_ids
let queues_ids analysis = MtIds.all_queues analysis.known_ids


let calling_ki analysis = Callstack.top_callsite analysis.curr_stack
let current_fun analysis = Callstack.top_kf analysis.curr_stack

let curr_events analysis =
  match analysis.curr_events_stack with
  | [] -> MtOptions.fatal "Invalid analysis stack"
  | h :: _ -> h

let on_current_trace analysis f =
  match analysis.curr_events_stack with
  | [] -> MtOptions.fatal "Invalid analysis stack"
  | h :: q ->
    analysis.curr_events_stack <- f h q :: q

(* Store a mthread event into the state of our analysis. *)
let register_event analysis ?(top=Callstack.top_call analysis.curr_stack) evt =
  on_current_trace analysis
    (fun cur _ -> Trace.add_event cur top evt)
;;

let register_multiple_events analysis evts =
  on_current_trace analysis
    (fun cur _ -> Trace.union evts cur)
;;

(* Store the memory state for the function which we finished analyzing *)
let register_memory_states analysis ~before ~after =
  MtOptions.debug ~level:2 "Recording states for %a"
    Kernel_function.pretty (current_fun analysis);
  on_current_trace analysis (fun cur _ ->  Trace.add_states cur ~before ~after);
;;

let push_function_call analysis =
  analysis.curr_events_stack <- Trace.empty :: analysis.curr_events_stack

let pop_function_call analysis =
  let top = Callstack.top_call analysis.curr_stack in
  match analysis.curr_stack.stack with
  | [] ->
    assert (List.length analysis.curr_events_stack = 1);
    on_current_trace analysis (fun cur _ -> Trace.add_prefix top cur);
  | _ :: _ ->
    match analysis.curr_events_stack with
    | [] | [_] -> MtOptions.fatal "Invalid analysis stack when popping calling"
    | trace_callee :: trace_caller :: q ->
      let trace_callee' = Trace.add_prefix top trace_callee in
      let new_trace = Trace.union trace_caller trace_callee' in
      analysis.curr_events_stack <- new_trace :: q


module OrderedThreads = struct

  let threads_children analysis =
    let th_tbl = analysis.all_threads in
    (* The inheritance table has at most as many entries as the general
       thread table *)
    let thread_creation = Id.Hashtbl.create (Id.Hashtbl.length th_tbl) in
    Id.Hashtbl.iter_sorted
      (fun _id thread ->
         match thread.th_parent with
         | None -> () (* This is the main thread *)
         | Some { th_id = parent } ->
           let children =
             try Id.Hashtbl.find thread_creation parent
             with Not_found -> []
           in
           Id.Hashtbl.replace thread_creation parent (thread :: children)
      ) th_tbl;
    thread_creation
  ;;

  let creation_map analysis =
    let h = threads_children analysis in
    (* Not really optimized, but we don't really care here. Mostly,
       threads are created by one single thread, the main one *)
    let rec all_children acc th =
      let immediate_children = try Id.Hashtbl.find h th.th_id with Not_found -> []
      and do_child acc th' =
        let acc' = Id.Set.add th'.th_id acc in
        all_children acc' th'
      in
      List.fold_left do_child acc immediate_children
    in
    fold_threads analysis Id.Map.empty
      (fun th map ->
         let children = all_children Id.Set.empty th in
         Id.Map.add th.th_id children map
      )

  (* Iter a function f over program threads following the an order compatible
     with the partial order induced by thread creation *)
  let ordered_iter analysis =
    let creation_tbl = threads_children analysis in
    fun f initial ->
      let rec do_thread value th =
        let v = f th value in
        try
          let children = Id.Hashtbl.find creation_tbl th.th_id in
          List.iter (do_thread v) children;
        with Not_found -> ()

      in
      do_thread initial analysis.main_thread
  ;;

  let ordered_fold f acc analysis =
    let creation_tbl = threads_children analysis in
    let rec do_thread_id_list acc thlist =
      match thlist with
      | [] -> acc
      | _ :: _ ->
        let new_acc, next_level =
          List.fold_left
            (fun (glob_acc, next_acc) th ->
               let children =
                 try Id.Hashtbl.find creation_tbl th.th_id
                 with Not_found -> [] in
               (f glob_acc th, children @ next_acc)
            ) (acc, []) thlist in
        do_thread_id_list new_acc next_level
    in do_thread_id_list acc [analysis.main_thread]
  ;;
end


let should_compute_thread th =
  (Id.equal th.th_id MtIds.id_main_thread)  ||
  (let name = th.th_id.id_name in
   (not (Datatype.String.Set.mem name (MtOptions.SkipThreads.get ()))) &&
   let only = MtOptions.OnlyThreads.get () in
   Datatype.String.Set.is_empty only || Datatype.String.Set.mem name only
  )
