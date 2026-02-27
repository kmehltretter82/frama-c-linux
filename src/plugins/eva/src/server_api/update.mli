(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Server

(** {2 Signals} *)

(** Signal emitted when the computation state of Eva changes. *)
val computation_signal : Request.signal

(** Signal emitted when the set of selected callstacks changes. *)
val callstack_signal : Request.signal

(** All signals above. *)
val signals : Request.signal list


(** {2 Hooks} *)

(** Adds an hook applied when the computation state of Eva changes. *)
val add_computation_hook : (unit -> unit) -> unit

(** Adds an hook applied when the set of selected callstacks changes. *)
val add_callstack_hook : (unit -> unit) -> unit

(** All hooks above. *)
val add_hook : (unit -> unit) -> unit


(** {2 States} *)

module CurrentCallstacks : State_builder.List_ref with type data = Callstack.t list
