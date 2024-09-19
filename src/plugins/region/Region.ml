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



(* API GETTERS *)
let get_map (f:kernel_function) : map = Code.domain f



let get_id _map region = Memory.id region.Memory.node
let get_region map id =
  try Some (Memory.region map.Code.map @@ Memory.forge id)
with Not_found -> None



let cvar (map:map) (var:varinfo) =
  try Some (Memory.region map.Code.map (Memory.lval map.Code.map ((Var var), NoOffset)))
with Not_found -> None

let field (map:map) (region:region) (field:fieldinfo) =
  try Some (Memory.region map.Code.map (Memory.offset map.Code.map region.node (Field (field, NoOffset))))
with Not_found -> None

let shift (_map:map) region (_ty:typ) = (* TODO *)
  try Some region
  with Not_found -> None


let base_addr _map region = (* TODO *) region



(* API POINTERS *)
let points_to (map:map) (region:region) : region option =
  Option.map (Memory.region map.Code.map) @@ Memory.cpointed map.map region.Memory.node

let pointed_by (map:map) (region:region) : region list =
  List.map (Memory.region map.Code.map) @@ Memory.cpointed_by map.Code.map region.Memory.node


(* COMPARATOR *)
let equal map r1 r2 = get_id map r1 == get_id map r2


module Reachable = struct

  module Imap = Map.Make(Int)

  let is_reachable map source target =
    let accessible = ref false in
    let q = Queue.create () in
    Queue.push source q ;
    let visited = ref Imap.empty in
    while not !accessible && not @@ Queue.is_empty q do
      let region = Queue.pop q in
      if not @@ Imap.mem (get_id map region) !visited then begin
        visited := Imap.add (get_id map region) region !visited ;
        List.iter (fun r -> Queue.push (Memory.region map r) q) region.Memory.parents ;
        accessible := equal map target region ;
      end
    done;
    !accessible

end

let included map r1 r2 : bool = Reachable.is_reachable map.Code.map r1 r2


let separated map r1 r2 =
  not (Reachable.is_reachable map.Code.map r1 r2)
  && not (Reachable.is_reachable map.Code.map r2 r1)



(* API ITERATOR *)
let iter (map:map) (f:region -> unit) : unit =
  Memory.iter map.map f


(* API PRINTER *)
let pp_region fmt region : unit = Memory.pp_region fmt region




(* API ACCESS *)
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
