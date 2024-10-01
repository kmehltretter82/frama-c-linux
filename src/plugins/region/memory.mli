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

open Cil_types

type node

type range = {
  label: string ;
  offset: int ;
  length: int ;
  cells: int ;
  data: node ;
}

type region = {
  node: node ;
  parents: node list ;
  roots: varinfo list ;
  labels: string list ;
  types: typ list ;
  fields: Fields.domain ;
  reads: Access.acs list ;
  writes: Access.acs list ;
  shifts: Access.acs list ;
  sizeof: int ;
  ranges: range list ;
  pointed: node option ;
}

type map

val pp_node : Format.formatter -> node -> unit
val pp_region : Format.formatter -> region -> unit

(** Initially unlocked. *)
val create : unit -> map

(** Default locked status is inherited from the copied map. *)
val copy : ?locked:bool -> map -> map

(** Lock the map. No more access nor merge can be added into the map. *)
val lock : map -> unit

(** Unlock the map. *)
val unlock : map -> unit

val id : node -> int
val forge : int -> node
val equal : map -> node -> node -> bool
val node : map -> node -> node
val nodes : map -> node list -> node list

val iter : map -> (region -> unit) -> unit
val iter_node : map -> (node -> unit) -> unit
val region : map -> node -> region
val regions : map -> region list
val parents : map -> node -> node list
val roots : map -> node -> varinfo list

val new_chunk : map -> ?size:int -> ?ptr:node -> ?pointed:node -> unit -> node
val add_root : map -> Cil_types.varinfo -> node
val add_label : map -> string -> node
val add_field : map -> node -> fieldinfo -> node
val add_index : map -> node -> typ -> int -> node
val add_points_to : map -> node -> node -> unit
val add_value : map -> node -> typ -> node option

val read : map -> node -> Access.acs -> unit
val write : map -> node -> Access.acs -> unit
val shift : map -> node -> Access.acs -> unit

val merge : map -> node -> node -> unit
val merge_all : map -> node list -> unit
val merge_copy : map -> l:node -> r:node -> unit

val cvar : map -> varinfo -> node
val field : map -> node -> fieldinfo -> node
val index : map -> node -> typ -> node
val lval : map -> lval -> node
val exp : map -> exp -> node option

val points_to : map -> node -> node option
val pointed_by : map -> node -> node list

val included : map -> node -> node -> bool
val separated : map -> node -> node -> bool

val reads : map -> node -> typ list
val writes : map -> node -> typ list
val shifts : map -> node -> typ list
