(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `IIG'.                       *)
(*                                                                        *)
(*  Copyright (C) 2018                                                    *)
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

module Table : FCHashtbl.S with type key = Dependency_types.symbolic_location

type t = private {
  graph: Imprecision_graph.t;
  table: Imprecision_graph.vertex Table.t;
  is_folded_base: Cil_types.varinfo -> bool;
  is_hidden_base: Cil_types.varinfo -> bool;
  mutable roots: Imprecision_graph.vertex list;
}

val create :
  ?is_folded_base:(Cil_types.varinfo -> bool) ->
  ?is_hidden_base:(Cil_types.varinfo -> bool) -> unit -> t

val add_lval : ?depth_limit:int -> t -> Cil_types.kinstr -> Cil_types.lval -> unit
