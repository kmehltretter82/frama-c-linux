(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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


type t

module Widen_Hints = Datatype.Integer.Set
type size_widen_hint = Integer.t
type generic_widen_hint = Widen_Hints.t

include Datatype.S_with_collections with type t := t
include Lattice_type.Full_AI_Lattice_with_cardinality
  with type t := t
   and type widen_hint = size_widen_hint * generic_widen_hint


val zero : t
val one : t
val minus_one : t
val zero_or_one : t

val positive_integers : t
val negative_integers : t

val inject_singleton : Integer.t -> t
val inject_range : Integer.t option -> Integer.t option -> t
val inject_interval:
  min: Integer.t option -> max: Integer.t option ->
  rem: Integer.t -> modu: Integer.t ->
  t
val make:
  min: Integer.t option -> max: Integer.t option ->
  rem: Integer.t -> modu: Integer.t ->
  t

val create_all_values: signed:bool -> size:int -> t

val min_int : t -> Integer.t option
val max_int : t -> Integer.t option
val min_max_rem_modu :
  t -> Integer.t option * Integer.t option * Integer.t * Integer.t
val min_and_max :
  t -> Integer.t option * Integer.t option

exception Not_Singleton_Int
val project_int : t -> Integer.t
val is_small_set: t -> bool
val project_small_set: t -> Integer.t list option


val is_singleton: t -> bool
val cardinal_zero_or_one : t -> bool
val cardinal: t -> Integer.t option
val cardinal_estimate: size:Integer.t -> t -> Integer.t
val cardinal_less_than : t -> int -> int
val cardinal_is_less_than: t -> int -> bool

val is_bottom: t -> bool

val is_zero: t -> bool
val contains_zero : t -> bool
val contains_non_zero : t -> bool

val add : t -> t -> t
val add_under : t -> t -> t
val add_singleton: Integer.t -> t -> t

val neg : t -> t
val sub : t -> t -> t
val sub_under: t -> t -> t

val scale : Integer.t -> t -> t
val scale_div : pos:bool -> Integer.t -> t -> t
val scale_div_under : pos:bool -> Integer.t -> t -> t
val scale_rem : pos:bool -> Integer.t -> t -> t

val mul : t -> t -> t
val div : t -> t -> t
val c_rem : t -> t -> t
val shift_left:  t -> t -> t
val shift_right: t -> t -> t

val bitwise_and : t -> t -> t
val bitwise_or : t -> t -> t
val bitwise_xor : t -> t -> t
val bitwise_signed_not: t -> t
val bitwise_unsigned_not: size:int -> t -> t

val cast_int_to_int : size:Integer.t -> signed:bool -> t -> t

val subdivide: t -> t * t

val extract_bits: start:Integer.t -> stop:Integer.t -> t -> t

val all_values: size:Integer.t -> t -> bool

val overlaps: partial:bool -> size:Integer.t -> t -> t -> bool

val fold_int : (Integer.t -> 'a -> 'a) -> t -> 'a -> 'a

val get_small_cardinal: unit -> int
val set_small_cardinal: int -> unit

val rehash: t -> t
