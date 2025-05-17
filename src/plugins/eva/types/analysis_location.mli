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

(** Analysis locations. *)

(** Analysis location of globals. *)
type global = Cil_types.global

(** Analysis location of locals: a statement and its associated callstack. *)
type local = Cil_types.stmt * Callstack.t

(** Analysis location. *)
type t =
  | Global of global
  | Local of local

module type S = sig
  include Datatype.S_with_collections

  val loc : t -> Cil_types.location
  (** [loc aloc] returns the source location of the given analysis location. *)

  val pos : t -> Filepath.position
  (** [pos aloc] returns the source file of the given analysis location. *)

  val pretty_loc : Format.formatter -> t -> unit
  (** Pretty-print the [Analysis_location] as a location in a source file. In
      the case of a local analysis location, the short callstack leading to that
      location is also printed. *)
end

module Global : S with type t = global
module Local : S with type t = local
include S with type t := t

val callstack : t -> Callstack.t option
(** [callstack aloc] returns the callstack of an analysis location if it is
    a local one, or [None] otherwise. *)

val of_stmt : Cil_types.stmt -> t
(** [of_stmt stmt] creates the local analysis location from the statement
    [stmt]. This should only be called during the analysis of a function as the
    current callstack must be available. *)

val of_call : ('a, 'b) Eval.call -> t
(** [of_call call] creates the global or local analysis location from the call
    information [call]. If this is the entry point of the analysis (i.e. the
    callsite is [Kglobal]) then the analysis location will be global. If there
    is a statement callsite then the analysis location will be local. *)

val of_kinstr_lval : Cil_types.kinstr -> Eva_ast.lval -> t
(** [of_kinstr_lval kinstr lval] creates the global or local analysis location
    from [kinstr] and [lval]. There are three distinct cases:
    - [kinstr] is a [Kstmt]: the function returns the local analysis location of
      the statement as with {!of_stmt}. This should only be called during the
      analysis of a function as the current callstack must be available.
    - [kinstr] is a [Kglobal] and [lval] is a [Var]: the function returns the
      global analysis location of the varinfo.
    - Otherwise this is an error case and a [fatal] is raised. *)
