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

(** Memory dependencies of an expression. *)
type t = {
  data: Locations.Zone.t;
  (** Memory zone directly required to evaluate the given expression. *)
  indirect: Locations.Zone.t;
  (** Memory zone read to compute data addresses. *)
}

include Datatype.S with type t := t

val pretty_precise: Format.formatter -> t -> unit
val pretty_debug: Format.formatter -> t -> unit

(* Constructors *)

val top : t
val bottom : t
val data : Locations.Zone.t -> t
val indirect : Locations.Zone.t -> t

(* Conversion *)

val to_zone : t -> Locations.Zone.t

(* Mutators *)

val add_data : t -> Locations.Zone.t -> t
val add_indirect : t -> Locations.Zone.t -> t

(* Map *)

val map : (Locations.Zone.t -> Locations.Zone.t) -> t -> t

(* Lattice operators *)

val is_included : t -> t -> bool
val join : t -> t -> t
val narrow : t -> t -> t
[@@@ api_end]
