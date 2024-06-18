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

include Graph.Sig.G
  with type V.t = node
   and type E.t = node * dependency * node

module Node : Datatype.S_with_collections with type t = node

module Dependency : Graph.Sig.COMPARABLE with type t = dependency

val create : ?size:int -> unit -> t

val create_node :
  node_kind:node_kind ->
  node_locality:node_locality -> t -> node

val remove_node : t -> node -> unit

val update_node_values : node ->
  typ:Cil_types.typ -> cvalue:Cvalue.V.t -> taint:Eva.Results.taint option ->
  unit

val create_dependency : t -> origin:origin -> kind:dependency_kind ->
  node -> node -> node * dependency * node

val remove_dependency : t -> node * dependency * node -> unit
val remove_dependencies : t -> node -> unit

val find_independant_nodes : t -> node list -> node list
val bfs : ?iter_succ:((node -> unit) -> t -> node -> unit) -> ?limit:int ->
  t -> node list -> node list

val output_to_dot : out_channel -> t -> unit
