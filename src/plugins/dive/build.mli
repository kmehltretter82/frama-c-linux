(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

type t

val create : unit -> t
val clear : t -> unit (* reset to almost an empty context,
                         but keeps folded and hidden bases *)

val get_graph : t -> Imprecision_graph.t
val get_roots : t -> Graph_types.node list

val unfold_base : t -> Cil_types.varinfo -> unit
val fold_base : t -> Cil_types.varinfo -> unit
val hide_base : t -> Cil_types.varinfo -> unit
val unhide_base : t -> Cil_types.varinfo -> unit

val find_node : t -> int -> Graph_types.node

val add_lval : ?depth:int -> t -> Cil_types.kinstr -> Cil_types.lval -> unit
val add_var : ?depth:int -> t -> Cil_types.varinfo -> unit
val add_alarm : ?depth:int -> t -> Cil_types.stmt -> Alarms.alarm -> unit
val add_function_alarms : ?depth:int -> t -> Cil_types.kernel_function -> unit
val explore_from_node : depth:int -> t -> Graph_types.node -> unit

val show : ?depth:int -> t -> Graph_types.node -> unit
val hide : t -> Graph_types.node -> unit

val take_last_differences : t -> Graph_types.graph_diff
