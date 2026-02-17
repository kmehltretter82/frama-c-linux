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


module ThreadTable : State_builder.Hashtbl with type key = Thread.t
                                            and type data = thread_summary

type access

val access_zone: access -> Locations.Zone.t
val access_kind: access -> Mt_shared_vars_types.access_kind
val access_protection: access -> Mt_shared_vars_types.protection
val access_id: access -> string

module AccessTable : State_builder.Hashtbl
  with type key = access
   and type data = Cil_datatype.Location.Set.t


(** Computes the summary from an analysis state. *)
val compute : Mt_thread.analysis_state -> unit

(** Clears summary. *)
val clear : unit -> unit
