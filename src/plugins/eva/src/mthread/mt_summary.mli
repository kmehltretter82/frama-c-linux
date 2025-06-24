(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Summary of an Mthread analysis. *)

type mutex_summary = {
  taken : Mutex.Set.t;
  (** Set of locks taken. *)
  released : Mutex.Set.t;
  (** Set of locks released. *)
}

type queue_summary = {
  created : Mqueue.Set.t;
  (** Set of message queues created. *)
  receivers : Mqueue.Set.t;
  (** Set of message queues receiving some message. *)
  senders : Mqueue.Set.t;
  (** Set of message queues sending some messages. *)
}

type shared_var_summary = {
  read : Locations.Zone.Set.t;
  (** Shared locations read. *)
  written : Locations.Zone.Set.t
  (** Shared locations written. *)
}

type thread_summary = {
  locks : mutex_summary;
  mqueues : queue_summary;
  shared_vars : shared_var_summary;
}

type protected_access = {
  zone : Locations.Zone.t;
  access_kind : Mt_shared_vars_types.AccessKind.t;
  protection_kind : Mt_shared_vars_types.ProtectionKind.t;
}
module ProtectedAccessDatatype : Datatype.S_with_collections
  with type t = protected_access

module ThreadTable : State_builder.Hashtbl with type key = Thread.t
                                            and type data = thread_summary

module AccessTable : State_builder.Hashtbl
  with type key = ProtectedAccessDatatype.t
   and type data = Mt_shared_vars_types.AccessLocationSet.t


(** Computes the summary from an analysis state. *)
val compute : Mt_thread.analysis_state -> unit

(** Clears summary. *)
val clear : unit -> unit
