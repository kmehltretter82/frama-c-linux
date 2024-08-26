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

(* -------------------------------------------------------------------------- *)
(* --- Region Analysis API                                                --- *)
(* -------------------------------------------------------------------------- *)


open Cil_types

type region = Memory.region

module R : Qed.Collection.S with type t = region =
  Qed.Collection.Make(struct
    type t = region
    let hash r = Memory.id r.Memory.node
    let equal r1 r2 = (hash r1 == hash r2)
    let compare r1 r2 = (hash r1) - (hash r2)
  end)


type map = Code.domain
let get_map (f:kernel_function) : map = Code.domain f

(** @raise Not_found *)
let cvar (map:map) (var:varinfo) : region =
  Memory.region map.map (Memory.lval map.map ((Var var), NoOffset))

let field (map:map) (region:region) (field:fieldinfo) : region =
  Memory.region map.map (Memory.offset map.map region.node (Field (field, NoOffset)))

let index (_:map) (_:region) (_:typ) : region = (* TODO *) raise Not_found


let points_to (map:map) (region:region) : region option =
  Option.map (Memory.region map.map) @@ Memory.cpointed map.map region.Memory.node

let pointed_by (map:map) (region:region) : region list =
  List.map (Memory.region map.map) @@ Memory.cpointed_by map.map region.Memory.node


let iter (map:map) (f:region -> unit) : unit =
  Memory.iter map.map f


let pp_region fmt region : unit = Memory.pp_region fmt region




type acs = {
    acs_read  : typ list;
    acs_write : typ list;
    acs_shift : typ list;
}
let empty_acs = {
  acs_read  = [];
  acs_write = [];
  acs_shift = [];
}

let accesses (region:region) : acs =
  {
    acs_read  = List.map Access.typeof region.Memory.reads ;
    acs_write = List.map Access.typeof region.Memory.writes ;
    acs_shift = List.map Access.typeof region.Memory.shifts ;
  }
