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

open Bottom.Type

include Datatype.S_with_collections

val rehash: t -> t

val bottom: t

val inject_singleton: Integer.t -> t
val inject_array: Integer.t array -> int -> t

val to_list: t -> Integer.t list

val remove: t -> Integer.t -> t or_bottom

val one: t
val zero: t
val minus_one: t
val zero_or_one: t

val min: t -> Integer.t
val max: t -> Integer.t

val cardinal: t -> int

val mem: Integer.t -> t -> int

val for_all: (Integer.t -> bool) -> t -> bool
val exists: (Integer.t -> bool) -> t -> bool

val iter: (Integer.t -> unit) -> t -> unit
val fold: ('a -> Integer.t -> 'a) -> 'a -> t -> 'a
val map: (Integer.t -> Integer.t) -> t -> t
val filter: (Integer.t -> bool) -> t -> t or_bottom

exception Empty
val map_reduce: (Integer.t -> 'a) -> ('a -> 'a -> 'a) -> t -> 'a

type set_or_top = [ `Set of t | `Top of Integer.t * Integer.t * Integer.t ]

val is_included: t -> t -> bool
val join: t -> t -> [`Set of t | `Top of (Integer.t * Integer.t * Integer.t)]
val link: t -> t -> set_or_top
val meet: t -> t -> t or_bottom
val narrow: t -> t -> t or_bottom

val intersects: t -> t -> bool

val diff_if_one: t -> t -> t or_bottom

val add_singleton: Integer.t -> t -> t
val add: t -> t -> set_or_top
val add_under: t -> t -> set_or_top
val neg: t -> t

val mul: t -> t -> set_or_top

val c_rem: t -> t -> set_or_top

val scale: Integer.t -> t -> t
val scale_div: pos:bool -> Integer.t -> t -> t or_bottom
val scale_rem: pos:bool -> Integer.t -> t -> set_or_top

val bitwise_signed_not: t -> t

val subdivide: t -> t * t


(**/**)

(* This is used by the Value plugin. Do not use. *)
val set_small_cardinal: int -> unit
