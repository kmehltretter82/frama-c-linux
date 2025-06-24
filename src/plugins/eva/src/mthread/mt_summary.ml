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

type protected_access = {
  zone : Locations.Zone.t;
  access_kind : AccessKind.t;
  protection_kind : ProtectionKind.t;
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

module ProtectedAccess = struct
  include Datatype.Serializable_undefined

  type t = protected_access [@@deriving eq, ord]

  let name = "Eva.Mthread.Mt_summary.ProtectedAccessSummary"
  let reprs =
    List.fold_left
      (fun acc zone ->
         List.fold_left
           (fun acc access_kind ->
              List.fold_left
                (fun acc protection_kind ->
                   { zone; access_kind; protection_kind } :: acc)
                acc
                ProtectionKind.reprs)
           acc
           AccessKind.reprs)
      []
      Locations.Zone.reprs
  let structural_descr =
    Structural_descr.t_record [| Locations.Zone.packed_descr;
                                 AccessKind.packed_descr;
                                 ProtectionKind.packed_descr; |]
  let hash { zone; access_kind; protection_kind } =
    Hashtbl.hash
      (Locations.Zone.hash zone,
       AccessKind.hash access_kind,
       ProtectionKind.hash protection_kind)
  let pretty fmt { zone; access_kind; protection_kind } =
    Format.fprintf fmt "%a>%a>%a"
      Locations.Zone.pretty zone
      AccessKind.pretty access_kind
      ProtectionKind.pretty protection_kind
end

module ProtectedAccessDatatype = Datatype.Make_with_collections (ProtectedAccess)


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
  |> AccessLocationSet.of_list

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
       let protection_kinds : ProtectionKind.t list =
         let locked_mutexes = get_locked_mutexes_for_access node_id_access in
         if MutexPresence.is_empty locked_mutexes then
           [ Unprotected ]
         else
           MutexPresence.KeySet.fold
             (fun mutex acc ->
                let presence = MutexPresence.find protection_mutexes mutex in
                let protection : ProtectionKind.t =
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
              LocationsByAccess.add (access_kind, protection) locs acc)
           LocationsByAccess.empty
           protection_kinds
       in
       ProtectedAccessesByZone.add_binding ~exact:false acc zone (`Value lba))
    node_access_set
    ProtectedAccessesByZone.empty


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

module AccessTable =
  State_builder.Hashtbl
    (ProtectedAccessDatatype.Hashtbl)
    (AccessLocationSet)
    (struct
      let name = "Eva.Mthread.Mt_summary.AccessSummary"
      let size = 11
      let dependencies = [ Ast.self ]
    end)

let compute_access_summary analysis =
  let accesses = analysis.concurrent_accesses_by_nodes in
  let mutexes_by_zone =
    Mt_mutexes.mutexes_protecting_zones' accesses
  in
  let aux = compute_node_access_summary mutexes_by_zone in
  let r1 = List.map aux accesses in
  let accesses_by_zone =
    List.fold_left
      (fun r r' -> ProtectedAccessesByZone.join r r')
      ProtectedAccessesByZone.empty
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
  ProtectedAccessesByZone.fold
    (fun zone accesses () ->
       let accesses = Eval.Top.non_top accesses in
       LocationsByAccess.iter
         (fun (access_kind, protection_kind) locations ->
            let access_key = { zone; access_kind; protection_kind } in
            AccessTable.add access_key locations)
         accesses)
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
