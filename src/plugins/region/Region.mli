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

(** Interface for the Region plug-in. *)


open Cil_types

type node
type map

val get_map : kernel_function -> map
val get_id : map -> node -> int
val get_node : map -> int -> node

val node : map -> node -> node
val nodes : map -> node list -> node list

val cvar : map -> varinfo -> node
val field : map -> node -> fieldinfo -> node
val index : map -> node -> typ -> node

val points_to : map -> node -> node option
val pointed_by : map -> node -> node list

val equal : map -> node -> node -> bool
val separated : map -> node -> node -> bool
val included : map -> node -> node -> bool

val iter : map -> (node -> unit) -> unit

val reads : map -> node -> typ list
val writes : map -> node -> typ list
val shifts : map -> node -> typ list

val pp_node : Format.formatter -> node -> unit
