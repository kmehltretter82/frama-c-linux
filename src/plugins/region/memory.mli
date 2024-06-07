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
  offset: int ;
  length: int ;
  cells: int ;
  data: node ;
}

type region = {
  node: node ;
  parents: node list ;
  roots: varinfo list ;
  types: typ list ;
  reads: Access.acs list ;
  writes: Access.acs list ;
  shifts: Access.acs list ;
  sizeof: int ;
  ranges: range list ;
  pointed: node option ;
}

type map

val pp_node : Format.formatter -> node -> unit
val pp_range : Format.formatter -> range -> unit
val pp_region : Format.formatter -> region -> unit

val create : unit -> map
val copy : map -> map

val root : map -> Cil_types.varinfo -> node
val cell : map -> ?size:int -> ?ptr:node -> ?root:varinfo -> unit -> node
val range : map -> size:int -> offset:int -> length:int -> data:node -> node

val id : node -> int
val forge : int -> node
val node : map -> node -> node
val nodes : map -> node list -> node list
val region : map -> node -> region
val iter : map -> (region -> unit) -> unit

val merge : map -> node -> node -> node
val read : map -> node -> Access.acs -> unit
val write : map -> node -> Access.acs -> unit
val shift : map -> node -> Access.acs -> unit
val points_to : map -> node -> node -> unit
