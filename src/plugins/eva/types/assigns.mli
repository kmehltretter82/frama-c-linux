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

(** Datastructures and common operations for the results of the From plugin. *)

[@@@ api_start]

module DepsOrUnassigned : sig

  type t =
    | DepsBottom (** Bottom of the lattice, never bound inside a memory state
                     at a valid location. (May appear for bases for which the
                     validity does not start at 0, currently only NULL.) *)
    | Unassigned (** Location has never been assigned *)
    | AssignedFrom of Deps.t (** Location guaranteed to have been overwritten,
                                 its contents depend on the [Deps.t] value *)
    | MaybeAssignedFrom of Deps.t  (** Location may or may not have been
                                       overwritten *)

  (** The lattice is [DepsBottom <= Unassigned], [DepsBottom <= AssignedFrom z],
      [Unassigned <= MaybeAssignedFrom] and
      [AssignedFrom z <= MaybeAssignedFrom z]. *)

  val top : t
  val equal : t -> t -> bool
  val may_be_unassigned : t -> bool
  val to_zone : t -> Locations.Zone.t
end

module Memory : sig
  include Lmap_bitwise.Location_map_bitwise with type v = DepsOrUnassigned.t

  val find : t -> Locations.Zone.t -> Locations.Zone.t
  (** Imprecise version of find, in which data and indirect dependencies are
      not distinguished *)

  val find_precise : t -> Locations.Zone.t -> Deps.t
  (** Precise version of find *)

  val find_precise_loffset : LOffset.t -> Base.t -> Int_Intervals.t -> Deps.t

  val add_binding : exact:bool -> t -> Locations.Zone.t -> Deps.t -> t
  val add_binding_loc : exact:bool -> t -> Locations.location -> Deps.t -> t
  val add_binding_precise_loc :
    exact:bool -> Locations.access -> t ->
    Precise_locs.precise_location -> Deps.t -> t
end

type t = {
  return : Deps.t
(** Dependencies for the returned value *);
  memory : Memory.t
(** Dependencies on all the zones modified by the function *);
}

include Datatype.S with type t := t

val top : t
val join : t -> t -> t

[@@@ api_end]

(** Extract the left part of a from result, ie. the zones that are written *)
val outputs : t -> Locations.Zone.t
