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

(** Interface for the Region plug-in.

    Each function is assigned a region map. Areas in the map represents l-values
    or, more generally, class of nodes. Regions are classes equivalences of
    nodes that represents a collection of addresses (at some program point).

    Regions can be subdivided into sub-regions. Hence, given two regions, either
    one is included into the other, or they are separated. Hence, given two
    l-values, if their associated regions are separated, then they can {i not}
    be aliased.

    Nodes are elementary elements of a region map. Variables maps to nodes, and
    one can move to one node to another by struct or union field or array
    element. Two disting nodes might belong to the same region. However, it is
    possible to normalize nodes and obtain a unique identifier for all nodes in
    a region.
*)


open Cil_types

type map
type node
val get_map : kernel_function -> map
val get_id : map -> node -> int
val get_node : map -> int -> node

(** Normalize node *)
val node : map -> node -> node

(** Normalize set of nodes *)
val nodes : map -> node list -> node list

(** Nodes are in the same region *)
val equal : map -> node -> node -> bool

(** First belongs to last *)
val included : map -> node -> node -> bool

(** Nodes can not be aliased *)
val separated : map -> node -> node -> bool

val cvar : map -> varinfo -> node
val field : map -> node -> fieldinfo -> node
val index : map -> node -> typ -> node

val lval : map -> lval -> node
val exp : map -> exp -> node option

val points_to : map -> node -> node option
val pointed_by : map -> node -> node list
val parents : map -> node -> node list
val roots : map -> node -> varinfo list

val iter : map -> (node -> unit) -> unit (** Iter over all regions *)

val reads : map -> node -> typ list
val writes : map -> node -> typ list
val shifts : map -> node -> typ list
