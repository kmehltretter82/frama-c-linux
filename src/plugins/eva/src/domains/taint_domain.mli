(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Domain for a taint analysis. *)

include Abstract_domain.Leaf
  with type value = Cvalue.V.t
   and type location = Precise_locs.precise_location

val registered: Abstractions.Domain.registered

type taint = | Direct | Indirect | Untainted

(** Is a memory zone tainted according to a given state? 
    If [name] is provided, only consider the taint of the given name. Otherwise,
    a memory zone is tainted as soon as it is tainted for at least one taint. *)
val is_tainted: ?name:string -> state -> Locations.Zone.t -> taint

(** Returns the list of taint names encountered by the taint analysis. *)
val taint_names: unit -> string list
