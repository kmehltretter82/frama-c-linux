(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Z integers with an additional top element. *)

include Datatype.S with type t = Z.t Lattice_bounds.or_top

val zero: t
val one: t
val minus_one: t
val top: t
val neg: t -> t

val of_int: int -> t

val is_zero: t -> bool
val is_top: t -> bool

val inject: Z.t -> t
val project: t -> Z.t
(** @raise Error_Top if the argument is {!Top}. *)
