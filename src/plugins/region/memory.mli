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

and layout =
  | Blob
  | Cell of int * node option
  | Compound of int * node Ranges.t

type region = private {
  parents: node list ;
  roots: varinfo list ;
  reads: Access.Set.t ;
  writes: Access.Set.t ;
  shifts: Access.Set.t ;
  layout: layout ;
}

val sizeof : layout -> int
val points_to : layout -> node option
val ranges : layout -> node Ranges.range list
val types : region -> typ list

val pp_node : Format.formatter -> node -> unit
val pp_layout : Format.formatter -> layout -> unit
val pp_region : Format.formatter -> node -> region -> unit

type map

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
val iter : map -> (node -> region -> unit) -> unit

val merge : map -> node -> node -> node
val read : map -> node -> Access.acs -> unit
val write : map -> node -> Access.acs -> unit
val shift : map -> node -> Access.acs -> unit
val pointer : map -> node -> node -> unit
