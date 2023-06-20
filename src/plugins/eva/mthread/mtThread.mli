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
open MtMemory.Types
open MtCil
open MtIds
open MtTypes
open MtSharedVarsTypes
open MtCfgTypes


type recompute_reason =
  | FirstIteration
  | NewMsgReceived
  | PotentialSharedVarsChanged
  | SharedVarsValuesChanged
  | InitialArgsChanged
  | InitialEnvChanged
;;

module RecomputeReason: sig
  type t = recompute_reason
  val compare: t -> t -> int
  val pretty: t Pretty_utils.formatter
end

module SetRecomputeReason: Set.S with type elt = recompute_reason

type priority =
  | PDefault (** No priority specified, but it is possible to specify one *)
  | PUnknown (** Contradictory priorities specified *)
  | PPriority of int (** Known priority *)

module Priority: Datatype.S with type t = priority


(** The representation of a thread *)
type thread = {
  th_id: MtIds.id (** Id of the thread for mthread *);
  th_parent : thread option (** Thread in which the thread is created. [None]
                                for the root thread *);
  th_fun : kernel_function (** Function which the thread executes *);
  th_stack : Callstack.t
(** Call stack resulting in the creation of the thread *);

  mutable th_init_state : Cvalue.Model.t
(** Memory state at the moment the thread is created *);

  mutable th_params : Cvalue.V.t list
(** Arguments to the the thread function *);

  mutable th_amap: Trace.t (** map interesting statements to sets
                               concurrent actions with their call stacks *);

  mutable th_to_recompute: SetRecomputeReason.t
(** Does this thread needs to be recomputed on the next iteration *);

  mutable th_read_written: AccessesByZone.map
(** Globals read and written by the thread, and at which statement *);

  mutable th_cfg : CfgNode.t (** Cfg for the current thread *);

  mutable th_read_written_cfg: AccessesByZoneNode.map
(** Globals read and written by the thread, and at which node
    in the cfg*);

  mutable th_values_written: MtMemory.Types.state
(** Join of all the values written by this thread in shared locations.
    Currently not contextual *);

  mutable th_projects: Project.t list
(** Copies of the analyses of the thread, most recent first *);

  mutable th_value_results: Eva_results.results option
(** Result of the last Value analysis of this thread *);

  mutable th_priority: priority
(** determines which threads execute without the possibility of being
    preempted by another thread. *);
}

module Thread : sig
  type t = thread

  val pretty: t Pretty_utils.formatter

  (** The functions below act on [th_id] *)
  val equal: t -> t -> bool
  val compare: t -> t -> int
  val hash: t -> int

  (** Auxiliary function that can be used to display a field [th_parent]
      in a consistent way *)
  val pretty_parent_id : Format.formatter -> thread option -> unit

  (** [one_creates_other th1 th2] returns [`Creates (th1, th2)]
      if [th1] creates [the] directly or through another threads,
      [`Creates(th2, th1)] if [th2] creates [th1], and [`Unrelated]
      otherwise *)
  val one_creates_other: t -> t -> [`Creates of t * t | `Unrelated]

  val recompute_because: thread -> recompute_reason -> unit

  module Set: Set.S with type elt = t
  module Map: Map.S with type key = t
  module Hashtbl: Hashtbl.S with type key = t
end


type threads_table = thread MtIds.Id.Hashtbl.t

type analysis_state = {
  all_threads : threads_table
(** List of all threads. Is kept (and can thus increase) from one
    iteration to the next *);

  mutable iteration: int (** Current iteration of the analysis *);

  mutable main_thread: thread (** Starting thread *);

  mutable curr_thread: thread (** Thread currently running. *);

  mutable curr_events_stack: Trace.t list (** Mthread events that have been
                                              found during the current analysis of the current thread. The list
                                              has the same height as [curr_stack]. The top of the list is the trace
                                              containing the events for the function being analyzed by Value, and
                                              so on until the top of the list. When the list is popped, the events
                                              of the callee are merged inside the trace of the caller. *);

  mutable memexec_cache: Trace.t Datatype.Int.Hashtbl.t
(** Cache for the results obtained during the analysis of the current
    thread *);

  mutable curr_stack: Callstack.t
(** stack of a multithread event. Asynchronously set by a callback and used
    by another, because of a slightly too restricted signature in the
    value analysis. *);

  mutable concurrent_accesses: Locations.Zone.t
(** Shared variables that have been detected in the analysis so far,
    with the crude analysis. Updated at the end of an iteration,
    and used to reach the fixpoint *);

  mutable precise_concurrent_accesses: Locations.Zone.t
(** Really shared variables that have been detected in the analysis so far,
    Subset of the previous field *);

  mutable concurrent_accesses_by_nodes:
    (Locations.Zone.t * SetNodeIdAccess.t) list
(** List of concurrent accesses that have been found. Used to
    compute the field [precise_concurrent_accesses] *);

  mutable known_ids: MtIds.known_ids
(** Information on the known threads, mutexes and queues found so
    far *);
}

val threads: analysis_state -> thread list
val thread_of_id: analysis_state -> id -> thread
val fold_threads: analysis_state -> 'a -> (thread -> 'a -> 'a) -> 'a
val iter_threads: analysis_state -> (thread -> unit) -> unit

val calling_ki: analysis_state -> kinstr
val current_fun: analysis_state -> kernel_function

val curr_events: analysis_state -> Trace.t

val register_event: analysis_state -> ?top:stack_elt -> event -> unit
val register_memory_states:
  analysis_state -> before:functions_states -> after:functions_states -> unit
val register_multiple_events:
  analysis_state -> Trace.t -> unit

val push_function_call: analysis_state -> unit
val pop_function_call: analysis_state -> unit


val should_compute_thread: thread -> bool

val mutexes_ids: analysis_state -> Id.Set.t
val queues_ids: analysis_state -> Id.Set.t

module OrderedThreads : sig


  val threads_children: analysis_state -> thread list Id.Hashtbl.t
  (** Create a table mapping each thread that creates a thread
      to the threads it creates *)

  val creation_map: analysis_state -> Id.set Id.map
  (** Map each existing threads to the id of the threads it recursively
      creates *)

  val ordered_fold : ('a -> thread -> 'a) -> 'a -> analysis_state -> 'a
  (** Fold a function f with accumulator acc
      over program threads following the partial order of thread creations.
  *)

  val ordered_iter : analysis_state -> (thread -> 'a -> 'a) -> 'a -> unit
  (** Iter a function f over program threads following the partial order of
      thread creations. The ['a] argument passed to the function is the
      value returned by the function on the creating thread
  *)
end
