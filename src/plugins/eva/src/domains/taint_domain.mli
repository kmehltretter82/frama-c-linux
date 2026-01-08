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
    If [indirect] is provided, return an [Indirect] taint if [indirect] is
    tainted (either directly or indirectly). *)
val is_tainted: state -> ?indirect:Locations.Zone.t -> Locations.Zone.t -> taint
