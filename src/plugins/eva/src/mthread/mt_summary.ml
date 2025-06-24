(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* Summary of an Mthread analysis, stored on disk for the Ivette component. *)

open Mt_types
open Mt_thread
open Mt_shared_vars_types

type mutex_summary = {
  taken : Mutex.Set.t;
  released : Mutex.Set.t;
}
[@@deriving eq, ord]

type queue_summary = {
  created : Mqueue.Set.t;
  receivers : Mqueue.Set.t;
  senders : Mqueue.Set.t;
}
[@@deriving eq, ord]

type shared_var_summary = {
  read : Locations.Zone.Set.t;
  written : Locations.Zone.Set.t;
}
[@@deriving eq, ord]

type thread_summary = {
  locks : mutex_summary;
  mqueues : queue_summary;
  shared_vars : shared_var_summary;
}
[@@deriving eq, ord]


(* ----- Datatypes for all above types. ----------------------------------- *)

module MutexSummary = struct
  include Datatype.Serializable_undefined

  type t = mutex_summary [@@deriving eq, ord]

  let empty = Mutex.Set.{ taken = empty; released = empty }

  let name = "Mt_summary.MutexSummary"
  let reprs = [ empty ]
  let structural_descr =
    let descr = Mutex.Set.packed_descr in
    Structural_descr.t_record [| descr; descr; |]
end

module QueueSummary = struct
  include Datatype.Serializable_undefined

  type t = queue_summary [@@deriving eq, ord]

  let empty = Mqueue.Set.{ created = empty; receivers = empty; senders = empty }

  let name = "Mt_summary.QueueSummary"
  let reprs = [ empty ]
  let structural_descr =
    let descr = Mqueue.Set.packed_descr in
    Structural_descr.t_record [| descr; descr; descr; |]
end

module SharedVarSummary = struct
  include Datatype.Serializable_undefined

  type t = shared_var_summary [@@deriving eq, ord]

  let empty = Locations.Zone.Set.{ read = empty; written = empty }

  let name = "Mt_summary.SharedVarSummary"
  let reprs = [ empty ]
  let structural_descr =
    let descr = Locations.Zone.Set.packed_descr in
    Structural_descr.t_record [| descr; descr; |]
end

module MutexSummaryDatatype = Datatype.Make (MutexSummary)
module QueueSummaryDatatype = Datatype.Make (QueueSummary)
module SharedVarSummaryDatatype = Datatype.Make (SharedVarSummary)

module ThreadSummary = struct
  include Datatype.Serializable_undefined

  type t = thread_summary [@@deriving eq, ord]

  let empty =
    { locks = MutexSummary.empty;
      mqueues = QueueSummary.empty;
      shared_vars = SharedVarSummary.empty; }

  let name = "Mt_summary.ThreadSummary"
  let reprs = [ empty ]
  let structural_descr =
    Structural_descr.t_record [| MutexSummaryDatatype.packed_descr;
                                 QueueSummaryDatatype.packed_descr;
                                 SharedVarSummaryDatatype.packed_descr; |]
end

module ThreadSummaryDatatype = Datatype.Make (ThreadSummary)


(** Map of zone to protected accesses. *)
module ProtectedAccessesByZone = struct
  module Lattice = struct
    include Eval.Top.Make_Datatype (LocationsByAccess)
    let top = `Top
    let default = `Value LocationsByAccess.empty
    let default_is_bottom = true
    let join l r =
      match l, r with
      | `Top, _ | _, `Top -> `Top
      | `Value l, `Value r -> `Value (LocationsByAccess.join l r)
    let is_included l r =
      match l, r with
      | _, `Top -> true
      | `Top, _ -> false
      | `Value l, `Value r ->
        LocationsByAccess.for_all
          (fun key l ->
             try
               let r = LocationsByAccess.find key r in
               AccessLocationSet.subset l r
             with Not_found -> false)
          l
  end

  include Lmap_bitwise.Make_bitwise (Lattice)
end


(* ----- Computation of the summary of one thread --------------------------- *)

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


let compute_thread_summary thread =
  Trace.fold' thread.Mt_thread.th_amap
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
    ThreadSummary.empty


(* ----- Summary for all threads -------------------------------------------- *)

module ThreadTable =
  State_builder.Hashtbl
    (Thread.Hashtbl)
    (ThreadSummaryDatatype)
    (struct
      let name = "Mt_summary.Summary"
      let size = 7
      let dependencies = [ Ast.self ]
    end)

let compute analysis =
  ThreadTable.clear ();
  let all_threads = Mt_thread.threads analysis in
  let threads = List.filter Mt_thread.should_compute_thread all_threads in
  List.iter
    (fun thread ->
       let thread_summary = compute_thread_summary thread in
       ThreadTable.replace thread.th_eva_thread thread_summary)
    threads;
  ThreadTable.mark_as_computed ()

let clear = ThreadTable.clear
