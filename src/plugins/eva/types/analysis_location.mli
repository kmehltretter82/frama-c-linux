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

  val kinstr : t -> Cil_types.kinstr
  (** [kinstr aloc] returns the kinstr associated to the analysis location. *)

  val pretty_loc : Format.formatter -> t -> unit
  (** Pretty-print the [Analysis_location] as a location in a source file. In
      the case of a local analysis location, the short callstack leading to that
      location is also printed. *)
end

module Global : S with type t = global
module Local : S with type t = local
include S with type t := t

val kf : t -> Cil_types.kernel_function option
(** [kf aloc] returns the kernel function of a local analysis location or [None] 
   if it is a global localion. *)

val stmt : t -> Cil_types.stmt option
(** [stmt aloc] returns the stmt of a local analysis location or [None] 
   if it is a global localion. *)

val callstack : t -> Callstack.t option
(** [callstack aloc] returns the callstack of a local analysis location or
    [None] if it is a global localion. *)

val local : Cil_types.stmt -> Callstack.t -> t
(** [local stmt cs] creates a local analysis location. *)

val global : Cil_types.global -> t
(** [global g] creates a global analysis location. *)

val is_local : t -> bool
(** [is_local aloc] returns true if aloc is a local analysis location. *)

val is_global : t -> bool
(** [is_global aloc] returns true if aloc is a global analysis location. *)

val of_varinfo : Cil_types.varinfo -> t
(** [of_varinfo vi] creates a global analysis location poiting to the
    variable definition of [vi]. *)

val of_kf : Cil_types.kernel_function -> t
(** [of_kf kf] creates a global analysis location poiting to the
    function definition of [kf] or its declaration if it is never defined. *)

val of_call : ('a, 'b) Eval.call -> t
(** [of_call call] creates the global or local analysis location from the call
    information [call]. If this is the entry point of the analysis (i.e. the
    callsite is [Kglobal]) then the analysis location will be global. If there
    is a statement callsite then the analysis location will be local. *)

val of_kinstr : Cil_types.kinstr -> Callstack.t -> t
(** [of_kinstr ki callstack] creates an analysis location at the given kinstr 
    and the given callstack. If [kinstr] is [Kstmt], it will be a local
    analysis location. Otherwise, the analysis location will be the top
    of the callstack or a global location if the callstack is empty. *)
