(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
