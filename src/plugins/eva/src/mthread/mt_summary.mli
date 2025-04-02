(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Summary of the analysis *)

type t

type lock_summary = {
  taken : Mutex.Set.t;
  (** Set of locks taken. *)
  released : Mutex.Set.t;
  (** Set of locks released. *)
}

type mqueue_summary = {
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
  locks : lock_summary;
  mqueues : mqueue_summary;
  shared_vars : shared_var_summary;
}

(** Compute the summary from an analysis state. *)
val compute : Mt_thread.analysis_state -> t

(** Iterate over all thread summaries for the given summary. *)
val iter : (Thread.t * thread_summary -> unit) -> t -> unit
