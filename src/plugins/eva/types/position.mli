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

(** Description of the current position of the analysis. *)

(** Local position: a statement and its associated callstack. *)
type local = Cil_types.stmt * Callstack.t

(** General position. *)
type t = private
  | RootCall of Cil_types.kernel_function
  | GlobalInit of Cil_types.varinfo
  | Local of local

module type S = sig
  include Datatype.S_with_collections

  val loc : t -> Cil_types.location
  (** [loc p] returns the source location of the given position. *)

  val pos : t -> Filepath.position
  (** [pos p] returns the source file of the given position. *)

  val kinstr : t -> Cil_types.kinstr
  (** [kinstr p] returns the kinstr associated to the position. *)

  val pretty_loc : Format.formatter -> t -> unit
  (** Pretty-print the [Analysis_location] as a location in a source file. In
      the case of a local position, the short callstack leading to that
      position is also printed. *)
end

module Local :
sig
  include S with type t = local

  val kf : t -> Cil_types.kernel_function
  (** [kf aloc] returns the kernel function of a local position. *)

  val stmt : t -> Cil_types.stmt
  (** [stmt aloc] returns the stmt of a local position. *)

  val callstack : t -> Callstack.t
  (** [callstack aloc] returns the callstack of a local position. *)
end


include S with type t := t

(** {2 Constructors} *)

val local : Cil_types.stmt -> Callstack.t -> t
(** [local stmt cs] creates a local position. *)

val root_call : Cil_types.kernel_function -> t
(** [root_call g] creates a position pointing to the root call of
    the analysis. *)

val global_init : Cil_types.varinfo -> t
(** [global_init vi] creates a position pointing to the global
    variable [vi]'s initialization. *)

(** {2 Conversions} *)

val of_kinstr : Cil_types.kinstr -> Callstack.t -> t
(** [of_kinstr ki callstack] creates a position at the given kinstr
    and the given callstack. If [kinstr] is [Kstmt], it will be a local
    position. Otherwise, the position will be the top
    of the callstack or a global position if the callstack is empty. *)

val of_local : local -> t
(** [of_local lpos] coerces a local position into a general position. *)


(** {2 Accessors} *)

val is_local : t -> bool
(** [is_local p] returns true if [p] is a local position. *)

val kf : t -> Cil_types.kernel_function option
(** [kf p] returns the kernel function of a local position [p] or [None]
    if it is a global localion. *)

val stmt : t -> Cil_types.stmt option
(** [stmt p] returns the stmt of a local position [p] or [None] if it is a
    global localion. *)

val callstack : t -> Callstack.t option
(** [callstack p] returns the callstack of a local position or [None] if it is a
    global location. *)
