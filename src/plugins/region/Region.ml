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
let get_region _map id = Memory.forge id



(** @raise Not_found *)
let cvar (map:map) (var:varinfo) : region =
  Memory.region map.map (Memory.lval map.map ((Var var), NoOffset))

(** @raise Not_found *)
let field (map:map) (region:region) (field:fieldinfo) : region =
  Memory.region map.map (Memory.offset map.map region.node (Field (field, NoOffset)))

(** @raise Not_found *)
let shift (_:map) region (_:typ) : region = (* TODO *) region


let base_addr _map region = (* TODO *) region



(* API POINTERS *)
let points_to (map:map) (region:region) : region option =
  Option.map (Memory.region map.map) @@ Memory.cpointed map.map region.Memory.node



(* COMPARATOR *)
let equal map r1 r2 = get_id map r1 == get_id map r2


module Reachable = struct

  module Imap = Map.Make(Int)
  module Q = Queue
  let is_reachable map source target =
    let rec aux visited siblings_to_visit parents_to_visit =
      if Queue.is_empty siblings_to_visit then aux visited parents_to_visit (Q.create())
      else
        let region = Queue.pop siblings_to_visit in
        if Imap.mem (get_id map region) visited then aux visited siblings_to_visit parents_to_visit
        else
          equal map region target ||
          let _ = List.iter (fun node -> Q.push (Memory.region map node) parents_to_visit) region.Memory.parents in
          aux (Imap.add (get_id map region) region visited) siblings_to_visit parents_to_visit
    in let source_queue = Q.create() in
    let _ = Q.push source source_queue in
    aux Imap.empty source_queue (Q.create())

end

let included map r1 r2 : bool = Reachable.is_reachable map r1 r2


let separated map r1 r2 =
  not (included map r1 r2) && not (included map r2 r1)



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
