(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(** {1 Interface for the Region plug-in}

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

(** {2 Memory Maps and Nodes} *)

type map
type node
val map : kernel_function -> map

(** Not normalized.
    Two nodes in the same equivalence class may have different identifiers. *)
val id : node -> int

(** Unique id of normalized node.
    This can be considered the unique identifier of the region equivalence
    class. *)
val uid : map -> node -> int

(** Returns a normalized node.
    @raises Not_found if not a valid node identifier. *)
val find : map -> int -> node

(** Normalized node.
    The returned node is the representative of the region equivalence class.
    There is one unique representative per equivalence class. *)
val node : map -> node -> node

(** Normalized list of nodes (normalized, uniques, sorted by id) *)
val nodes : map -> node list -> node list

(** {2 Region Properties}

    All functions in this section provide normalized nodes
    and shall never raise exception. *)

val points_to : map -> node -> node option
val pointed_by : map -> node -> node list

val size : map -> node -> int
val parents : map -> node -> node list
val roots : map -> node -> varinfo list
val labels: map -> node -> string list
val reads : map -> node -> typ list
val writes : map -> node -> typ list
val shifts : map -> node -> typ list

val typed : map -> node -> typ option
(** Full-sized cells with unique type access *)

val iter : map -> (node -> unit) -> unit

(** {2 Alias Analysis} *)

(** [equal m a b] checks if nodes [a] and [b] are in the same region. *)
val equal : map -> node -> node -> bool

(** [include m a b] checks if region [a] is a sub-region of [b] in map [m]. *)
val included : map -> node -> node -> bool

(** [separated m a b] checks if region [a] and region [b] are disjoint.
    Disjoints regions [a] and [b] have the following properties:
    - [a] is {i not} a sub-region of [b];
    - [b] is {i not} a sub-region of [a];
    - two l-values respectively localized in [a] and [b]
      can {i never} be aliased.
*)
val separated : map -> node -> node -> bool


(** [singleton m a] returns [true] when node [a] is guaranteed to have only
    one single address in its equivalence class. *)
val singleton : map -> node -> bool

(** [lval m lv] is region where the address of [l] lives in.
    The returned region is normalized.
    @raises Not_found if the l-value is not localized in the map *)
val lval : map -> lval -> node

(** [exp m e] is the domain of values that can computed by expression [e].
    The domain is [Some r] is [e] has a pointer type and any pointer computed by
    [e] lives in region [r]. The domain is [None] if [e] has a non-pointer
    scalar or compound type.
    @raises Not_found if the l-value is not localized in the map
*)
val exp : map -> exp -> node option

(** {2 Low-level Navigation through Memory Maps}

    For optimized access, all the fonctions in this section return
    unnormalized nodes and may raise [Not_found] for not localized routes. *)

(** Unormalized.
    @raises Not_found *)
val cvar : map -> varinfo -> node

(** Unormalized.
    @raises Not_found *)
val field : map -> node -> fieldinfo -> node

(** Unormalized.
    @raises Not_found *)
val index : map -> node -> typ -> node

(** Normalized list of leaf nodes. *)
val footprint : map -> node -> node list
