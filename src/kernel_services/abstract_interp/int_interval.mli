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

include Eva_lattice_type.Full_AI_Lattice_with_cardinality
  with type t := t
   and type widen_hint = Integer.t * Datatype.Integer.Set.t

val make:
  min:Integer.t option -> max:Integer.t option ->
  rem:Integer.t -> modu:Integer.t -> t

val inject_range: Integer.t option -> Integer.t option -> t

val min_and_max: t -> Integer.t option * Integer.t option

val min_max_rem_modu:
  t -> Integer.t option * Integer.t option * Integer.t * Integer.t

val mem: Integer.t -> t -> bool

val cardinal: t -> Integer.t option

val add : t -> t -> t
(** Addition of two integer (ie. not [Float]) ivals. *)
val add_under : t -> t -> t or_bottom
(** Underapproximation of the same operation *)
val add_singleton_int: Integer.t -> t -> t
(** Addition of an integer ival with an integer. Exact operation. *)

val neg : t -> t
(** Negation of an integer ival. Exact operation. *)


val scale: Integer.t -> t -> t
val scale_div: pos:bool -> Integer.t -> t -> t
val scale_div_under: pos:bool -> Integer.t -> t -> t or_bottom
val scale_rem: pos:bool -> Integer.t -> t -> t

val mul: t -> t -> t
val div: t -> t -> t or_bottom
val c_rem: t -> t -> t or_bottom

val subdivide: t -> t * t

val reduce_sign: t -> bool -> t or_bottom
val reduce_bit: int -> t -> bool -> t or_bottom

val fold_int: (Integer.t -> 'a -> 'a) -> t -> 'a -> 'a
