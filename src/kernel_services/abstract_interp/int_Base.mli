(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Big integers with an additional top element. *)

type i = Top | Value of Integer.t

include Datatype.S with type t = i

val zero: t
val one: t
val minus_one: t
val top: t
val neg: t -> t

val is_zero: t -> bool
val is_top: t -> bool

val inject: Integer.t -> t
val project: t -> Integer.t
(** @raise Error_Top if the argument is {!Top}. *)

val cardinal_zero_or_one: t -> bool
