(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

[@@@ api_start]

(** A call is identified by the function called and the call statement *)
type call = Cil_types.kernel_function * Cil_types.stmt

module Call : Datatype.S with type t = call

(** Eva callstacks. *)
type callstack = {
  thread: int;
  (* An identifier of the thread's callstack. *)
  entry_point: Cil_types.kernel_function;
  (** The first function function of the callstack. *)
  stack: call list;
  (** A call stack is a list of calls. The head is the latest call. *)
}

include Datatype.S_with_collections with type t = callstack

(** Prints a callstack without displaying call sites. *)
val pretty_short : Format.formatter -> t -> unit

(** Prints a hash of the callstack when '-kernel-msg-key callstack'
    is enabled (prints nothing otherwise). *)
val pretty_hash : Format.formatter -> t -> unit

(** [compare_lex] compares callstack lexicographically, slightly slower
    than [compare] but in a more natural order, giving more importance
    to the function at bottom of the callstack - the first functions called. *)
val compare_lex : t -> t -> int

(*** {2 Stack manipulation} *)

(*** Constructor *)
val init : ?thread:int -> Cil_types.kernel_function -> t

(** Adds a new call to the top of the callstack. *)
val push : Cil_types.kernel_function -> Cil_types.stmt -> t -> t

(** Removes the topmost call from the callstack. *)
val pop : t -> t option

val top : t -> (Cil_types.kernel_function * Cil_types.stmt) option
val top_kf : t -> Cil_types.kernel_function
val top_callsite : t -> Cil_types.kinstr
val top_call : t -> Cil_types.kernel_function * Cil_types.kinstr

(** Returns the function that called the topmost function of the callstack. *)
val top_caller : t -> Cil_types.kernel_function option

(** {2 Conversion} *)

(** Gives the list of kf in the callstack from the entry point to the top of the
    callstack (i.e. reverse order of the call stack). *)
val to_kf_list : t -> Cil_types.kernel_function list

(** Gives the list of call statements from the bottom to the top of the
    callstack (i.e. reverse order of the call stack). *)
val to_stmt_list : t -> Cil_types.stmt list

(** Gives the list of call from the bottom to the top of the callstack
    (i.e. reverse order of the call stack). *)
val to_call_list : t -> (Cil_types.kernel_function * Cil_types.kinstr) list

[@@@ api_end]

val pretty_debug : Format.formatter -> t -> unit
