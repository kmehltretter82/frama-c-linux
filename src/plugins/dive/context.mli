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

open Dive_types

type t

type element = Node of node | Edge of (node * dependency * node)

val create : unit -> t
val clear : t -> unit (* reset to almost an empty context,
                         but keeps folded and hidden bases, and hooks *)

val get_graph : t -> Dive_graph.t
val find_node : t -> int -> node
val get_max_dep_fetch_count : t -> int

val get_roots : t -> node list
val set_unique_root : t -> node -> unit
val add_root : t -> node -> unit
val remove_root : t -> node -> unit

val is_folded : t -> Cil_types.varinfo -> bool
val unfold : t -> Cil_types.varinfo -> unit
val fold : t -> Cil_types.varinfo -> unit

val is_hidden : t -> node_kind -> bool
val hide : t -> Cil_types.varinfo -> unit
val show : t -> Cil_types.varinfo -> unit

val add_node : t -> node_kind:node_kind -> node_locality:node_locality -> node
val remove_node : t -> node -> unit
val add_dep : t -> origin:origin -> kind:dependency_kind ->
  node -> node -> unit
val remove_node_deps : t -> node -> unit

val update_node_values : t -> node ->
  typ:Cil_types.typ ->
  cvalue:Locations.Location_Bytes.t -> taint:Eva.Results.taint option -> unit
val set_node_writes : t -> node -> origin list -> unit

val set_update_hook : t -> (element -> unit) -> unit
val set_remove_hook : t -> (element -> unit) -> unit
val set_clear_hook : t -> (unit -> unit) -> unit

