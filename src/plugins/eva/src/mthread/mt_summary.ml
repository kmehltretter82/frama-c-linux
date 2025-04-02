(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Summary of the analysis *)

open Mt_types
open Mt_thread

type lock_summary = {
  taken : Mutex.Set.t;
  released : Mutex.Set.t;
}
type mqueue_summary = {
  created : Mqueue.Set.t;
  receivers : Mqueue.Set.t;
  senders : Mqueue.Set.t;
}
type shared_var_summary = {
  read : Locations.Zone.Set.t;
  written : Locations.Zone.Set.t;
}
type thread_summary = {
  locks : lock_summary;
  mqueues : mqueue_summary;
  shared_vars : shared_var_summary;
}
type t = thread_summary Thread.Map.t

let empty_summary = {
  locks = { taken = Mutex.Set.empty ;
            released = Mutex.Set.empty };
  mqueues = { created = Mqueue.Set.empty ;
              receivers = Mqueue.Set.empty ;
              senders = Mqueue.Set.empty };
  shared_vars = { read = Locations.Zone.Set.empty ;
                  written = Locations.Zone.Set.empty };
}

let add_lock_taken id th_summary =
  let taken = Mutex.Set.add id th_summary.locks.taken in
  let locks = { th_summary.locks with taken } in
  { th_summary with locks }

let add_lock_released id th_summary =
  let released = Mutex.Set.add id th_summary.locks.released in
  let locks = { th_summary.locks with released } in
  { th_summary with locks }

let add_mqueue_created id th_summary =
  let created = Mqueue.Set.add id th_summary.mqueues.created in
  let mqueues = { th_summary.mqueues with created } in
  { th_summary with mqueues }

let add_mqueue_received_from id th_summary =
  let receivers = Mqueue.Set.add id th_summary.mqueues.receivers in
  let mqueues = { th_summary.mqueues with receivers } in
  { th_summary with mqueues }

let add_mqueue_sent_to id th_summary =
  let senders = Mqueue.Set.add id th_summary.mqueues.senders in
  let mqueues = { th_summary.mqueues with senders } in
  { th_summary with mqueues }

let add_shared_var_read zone th_summary =
  let read = Locations.Zone.Set.add zone th_summary.shared_vars.read in
  let shared_vars = { th_summary.shared_vars with read } in
  { th_summary with shared_vars }

let add_shared_var_written zone th_summary =
  let written = Locations.Zone.Set.add zone th_summary.shared_vars.written in
  let shared_vars = { th_summary.shared_vars with written } in
  { th_summary with shared_vars }

let compute analysis =
  let th_list = List.filter should_compute_thread (threads analysis) in
  List.fold_left
    (fun summary th ->
        let th_summary =
          Trace.fold' th.th_amap
            (fun action acc ->
              match action with
              | MutexLock id -> add_lock_taken id acc
              | MutexRelease id -> add_lock_released id acc
              | CreateQueue (id, _) -> add_mqueue_created id acc
              | ReceiveMsg (id, _, _) -> add_mqueue_received_from id acc
              | SendMsg (id, _) -> add_mqueue_sent_to id acc
              | VarAccess (Read, zone) -> add_shared_var_read zone acc
              | VarAccess (Write _, zone) -> add_shared_var_written zone acc
              | _ -> acc)
            empty_summary
        in
        Thread.Map.add th.th_eva_thread th_summary summary)
    Thread.Map.empty
    th_list

let iter f summary =
  Thread.Map.iter
    (fun th th_summary -> f (th, th_summary))
    summary
