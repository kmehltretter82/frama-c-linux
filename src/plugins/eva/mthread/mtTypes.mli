(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype
open MtCil
open MtMemory.Types
open MtIds


(** Kind of access to zones *)

type rw = Read | Write of Locations.location
module RW: Datatype.S with type t = rw


(** Multithread events *)

type event =
  | CreateThread of id
  | StartThread of id
  | SuspendThread of id
  | CancelThread of id
  | ThreadExit of value
  | MutexLock of id
  | MutexRelease of id
  | CreateQueue of id * int option
  | SendMsg of id * (slice * int)
  (** [SendMsg(id, (msg, size))]
      - [id]: id of the queue
      - [msg]: content of the message
      - [size]: size of the message
  *)
  | ReceiveMsg of id * pointer * int
  (** [ReceiveMsg(id, ptr, size)]
      - [id]: id of the queue
      - [ptr]: loc to which the message must be written
      - [size]: max size to read
  *)
  | VarAccess of rw * Locations.Zone.t (** Access to some shared variables *)
  | Dummy of string * value list


module Event : sig
  type t = event
  val equal: t -> t -> bool
  val hash: t -> int
  val pretty: t Pretty_utils.formatter
end


(** Maps from statements to multithread events, together with the context
    in which they occur *)

module EventsSet : sig
  include Set.S with type elt = event

  val pretty: ?sep:Pretty_utils.sformat -> unit -> Format.formatter -> t -> unit
  val threads_created : t -> id list
end
type events_set = EventsSet.t


(** Execution trace, mapping execution stacks to sets of events occurring
    at this point *)
module Trace : sig

  type t

  type data = private {
    trace_events: events_set;
    trace_states: state Stmt.Map.t; (* ??? *)
    trace_states_after: state Stmt.Map.t;
  }

  val empty : t
  val is_empty : t -> bool

  val add_event: t -> stack_elt -> event -> t
  val add_states: t -> before:functions_states -> after:functions_states -> t
  val add_prefix: stack_elt -> t -> t

  val find_at_stmt: t -> stmt -> (stack_elt * t) list

  val subtrace_at_call: t -> stack_elt -> t

  val at_root : t ->                 data option
  val at_call:  t -> stack_elt ->    data option

  val union: t -> t -> t

  val iter : t -> (Stack.t -> event -> unit) -> unit
  val iter' : t -> (event -> unit) -> unit
  val fold : t -> (Stack.t -> event -> 'a -> 'a) -> 'a -> 'a
  val fold' : t -> (event -> 'a -> 'a) -> 'a -> 'a
  val exists : t -> (Stack.t -> event -> bool) -> bool

  val find_events : (event -> bool) -> t -> events_set

  val pretty : Format.formatter -> t -> unit

  val no_deep_call: t -> bool

end


(** Live threads/taken mutexes at a given point of execution *)

type presence_flag = NotPresent | Present | MaybePresent

type presence

module Presence: sig
  type t = presence

  val pretty: t Pretty_utils.formatter

  val equal: t -> t -> bool
  val hash: t -> int
  val compare: t -> t -> int

  val empty: t
  val is_empty: t -> bool

  val find: t -> id -> presence_flag

  val add: id -> presence_flag -> t -> t

  val combine: t -> t -> t

  val only_present: t -> Id.Set.t

end
