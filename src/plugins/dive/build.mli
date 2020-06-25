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

open Cil_types
open Dive_types

type t

val create : unit -> t
val clear : t -> unit (* reset to almost an empty context,
                         but keeps folded and hidden bases *)

val get_graph : t -> Imprecision_graph.t
val get_roots : t -> node list

val unfold_base : t -> varinfo -> unit
val fold_base : t -> varinfo -> unit
val hide_base : t -> varinfo -> unit
val unhide_base : t -> varinfo -> unit

val find_node : t -> int -> node

val add_lval : t -> kinstr -> lval -> node
val add_var : t -> varinfo -> node
val add_alarm : t -> stmt -> Alarms.alarm -> node
val add_annotation : t -> stmt -> code_annotation -> node option
val add_stmt : t -> stmt -> node option
val add_property : t -> Property.t -> node option
val add_localizable : t -> Printer_tag.localizable -> node option

val explore : depth:int -> t -> node -> unit

val show : t -> node -> unit
val hide : t -> node -> unit

val reduce_to_horizon : t -> int option range -> node -> unit

val take_last_differences : t -> graph_diff
