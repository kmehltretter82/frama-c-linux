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

type queue_summary = {
  created : Mqueue.Set.t;
  receivers : Mqueue.Set.t;
  senders : Mqueue.Set.t;
}

type shared_var_summary = {
  read : Locations.Zone.Set.t;
  written : Locations.Zone.Set.t;
}

type thread_summary = {
  locks : mutex_summary;
  mqueues : queue_summary;
  shared_vars : shared_var_summary;
}

(* ----- Datatypes for all above types. ----------------------------------- *)

module MutexSummary = struct
  include Datatype.Serializable_undefined

  type t = mutex_summary

  let empty = Mutex.Set.{ taken = empty; released = empty }

  let name = "Mt_summary.MutexSummary"
  let reprs = [ empty ]
  let structural_descr =
    let descr = Mutex.Set.packed_descr in
    Structural_descr.t_record [| descr; descr; |]
end

module QueueSummary = struct
  include Datatype.Serializable_undefined

  type t = queue_summary

  let empty = Mqueue.Set.{ created = empty; receivers = empty; senders = empty }

  let name = "Mt_summary.QueueSummary"
  let reprs = [ empty ]
  let structural_descr =
    let descr = Mqueue.Set.packed_descr in
    Structural_descr.t_record [| descr; descr; descr; |]
end

module SharedVarSummary = struct
  include Datatype.Serializable_undefined

  type t = shared_var_summary

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

  type t = thread_summary

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


(* ----- Computation of the summary of one access node set ------------------ *)

module LocSet = Cil_datatype.Location.Set

module AccessProperty = Datatype.Pair_with_collections (AccessKind) (Protection)

(* Map binding access property (kind+protection) to a set of locations. *)
module LocationsByAccessProperty = struct
  include AccessProperty.Map
  include Make (LocSet)

  let hash map =
    let hash_binding key set = AccessProperty.hash key, LocSet.hash set in
    fold (fun key set acc -> Hashtbl.hash (acc, hash_binding key set)) map 0

  let join = union (fun _key a b -> Some (LocSet.union a b))

  let is_included l r =
    let is_included_binding key elt =
      try LocSet.subset elt (find key r)
      with Not_found -> false
    in
    for_all is_included_binding l
end

(** Map zone -> access property (kind+protection) -> set of locations. *)
module AccessPropertyByZone = struct
  module Lattice = struct
    include Lattice_bounds.Top.Bound_Lattice (LocationsByAccessProperty)
    let default = `Value LocationsByAccessProperty.empty
    let default_is_bottom = true
  end

  include Lmap_bitwise.Make_bitwise (Lattice)
end

let get_access_kind (rw, _, _) : AccessKind.t =
  match rw with
  | Read | ReadPos _ -> AccessRead
  | Write _ | WritePos _ -> AccessWrite

let get_mutexes_for_access mutexes (rw, _, _) =
  let open Mt_mutexes_types in
  let mutexes =
    match rw with
    | Read | ReadPos _ -> mutexes.mutexes_for_read
    | Write _ | WritePos _ -> mutexes.mutexes_for_write
  in
  match mutexes with
  | Unaccessed ->
    Mt_self.fatal "By construction, we are considering actual accesses"
  | Mutexes m -> m

let get_access_locs (_, node, _) =
  Mt_cfg_types.CfgNode.node_stmt node
  |> List.map Cil_datatype.Stmt.loc
  |> LocSet.of_list

let get_locked_mutexes_for_access (_, node, _) =
  node.Mt_cfg_types.cfgn_context.locked_mutexes

let compute_node_access_summary mutexes_by_zone (zone, node_access_set) =
  let open Mt_mutexes_types in
  let open Mt_cfg_types in
  let mutexes = MutexesByZone.find mutexes_by_zone zone in
  (* By construction, the zone is in the MutexesByZone *)
  let mutexes = Eval.Bottom.non_bottom mutexes in
  SetNodeIdAccess.fold
    (fun node_id_access acc ->
       let access_kind = get_access_kind node_id_access in
       let protection_mutexes = get_mutexes_for_access mutexes node_id_access in
       let locs = get_access_locs node_id_access in
       let protection_kinds : Protection.t list =
         let locked_mutexes = get_locked_mutexes_for_access node_id_access in
         if MutexPresence.is_empty locked_mutexes then
           [ Unprotected ]
         else
           MutexPresence.KeySet.fold
             (fun mutex acc ->
                let presence = MutexPresence.find protection_mutexes mutex in
                let protection : Protection.t =
                  match presence with
                  | NotPresent ->
                    Mt_self.fatal
                      "By construction, the mutexes from the access are present"
                  | MaybePresent -> MaybeProtected (Mutex.Set.singleton mutex)
                  | Present -> Protected (Mutex.Set.singleton mutex)
                in
                protection :: acc)
             (MutexPresence.all_present locked_mutexes)
             []
       in
       let lba =
         List.fold_left
           (fun acc protection ->
              LocationsByAccessProperty.add (access_kind, protection) locs acc)
           LocationsByAccessProperty.empty
           protection_kinds
       in
       AccessPropertyByZone.add_binding ~exact:false acc zone (`Value lba))
    node_access_set
    AccessPropertyByZone.empty


(* ----- Summary for all threads -------------------------------------------- *)

let info name : (module State_builder.Info_with_size) =
  (module struct
    let name = "Eva.Mt_summary." ^ name
    let size = 11
    let dependencies = [ Self.state ]
  end)

module ThreadTable =
  State_builder.Hashtbl
    (Thread.Hashtbl) (ThreadSummaryDatatype) (val info "ThreadTable")

let compute_threads_summary analysis =
  ThreadTable.clear ();
  let all_threads = Mt_thread.threads analysis in
  let threads = List.filter Mt_thread.should_compute_thread all_threads in
  List.iter
    (fun thread ->
       let thread_summary = compute_thread_summary thread in
       ThreadTable.replace thread.th_eva_thread thread_summary)
    threads;
  ThreadTable.mark_as_computed ()


(* ----- Summary for all accesses ------------------------------------------- *)

module Access =
  Datatype.Triple_with_collections (Locations.Zone) (AccessKind) (Protection)

type access = Access.t

let access_zone (zone, _, _) = zone
let access_kind (_, kind, _) = kind
let access_protection (_, _, protection) = protection
let access_id access = Format.asprintf "%a" Access.pretty access

module AccessTable =
  State_builder.Hashtbl (Access.Hashtbl) (LocSet) (val info "AccessTable")

let compute_access_summary analysis =
  let accesses = analysis.concurrent_accesses_by_nodes in
  let mutexes_by_zone =
    Mt_mutexes.mutexes_protecting_zones' accesses
  in
  let aux = compute_node_access_summary mutexes_by_zone in
  let r1 = List.map aux accesses in
  let accesses_by_zone =
    List.fold_left
      (fun r r' -> AccessPropertyByZone.join r r')
      AccessPropertyByZone.empty
      r1
  in
  let accesses_by_zone =
    match accesses_by_zone with
    | Top | Bottom ->
      Mt_self.fatal
        "By construction, accesses_by_zone cannot be Top or Bottom"
    | Map m -> m
  in
  AccessTable.clear ();
  let add_zone_accesses zone accesses =
    LocationsByAccessProperty.iter
      (fun (kind, protection) locations ->
         AccessTable.add (zone, kind, protection) locations)
      accesses
  in
  AccessPropertyByZone.fold
    (fun zones accesses () ->
       let accesses = Eval.Top.non_top accesses in
       try
         Locations.Zone.fold_i
           (fun base ivals () ->
              let zone = Locations.Zone.inject base ivals in
              add_zone_accesses zone accesses)
           zones
           ()
       with Abstract_interp.Error_Top ->
         add_zone_accesses Locations.Zone.top accesses)
    accesses_by_zone
    ();
  AccessTable.mark_as_computed ()


(* ----- Summary for everything --------------------------------------------- *)

let compute analysis =
  compute_threads_summary analysis;
  compute_access_summary analysis

let clear () =
  ThreadTable.clear ();
  AccessTable.clear ();
