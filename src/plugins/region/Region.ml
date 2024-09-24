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


module Node = struct

  type node = Memory.node
  type map = Code.domain



  (* API GETTERS *)
  let get_map (f:kernel_function) : map = Code.domain f


  let get_id map node = Memory.id (Memory.node map.Code.map node)
  let get_node map id = Memory.node map.Code.map @@ Memory.forge id



  let cvar (map:map) (var:varinfo) =
    Memory.node map.Code.map (Memory.lval map.Code.map ((Var var), NoOffset))

  let field (map:map) (node:node) (field:fieldinfo) =
    Memory.node map.Code.map
    @@ Memory.offset map.Code.map node (Field (field, NoOffset))

  let shift (_map:map) node (_ty:typ) = (* TODO *) node
  let index (map:map) node = Memory.index map.Code.map node

  let literal _map ~eid:_eid (_cst : Base.cstring) = raise Not_found
  let logical_node _map = raise Not_found
  let of_int_node _map = raise Not_found


  let base_addr _map node = (* TODO *) node



  (* API POINTERS *)
  let points_to (map:map) (node:node) : node option =
    Option.map (Memory.node map.Code.map)
    @@ Memory.cpointed map.map node

  let pointed_by (map:map) (node:node) : node list =
    List.map (Memory.node map.Code.map)
    @@ Memory.cpointed_by map.Code.map node


  (* COMPARATOR *)
  let equal map r1 r2 = Memory.eq_node map.Code.map r1 r2


  module Reachable = struct

    module Imap = Map.Make(Int)

    let is_reachable map source target : bool =
      let q = Queue.create () in
      let exception Reached in
      try
        let push r =
          if equal map target r then raise Reached else Queue.push r q
        in
        push source ;
        let visited = ref Imap.empty in
        while true do (*not !accessible && not @@ Queue.is_empty q do *)
          let node = Queue.pop q in
          if equal map target node then raise Exit else
          if not @@ Imap.mem (get_id map node) !visited then begin
            visited := Imap.add (get_id map node) node !visited ;
            List.iter push (Memory.parents map.Code.map node)
          end
        done ;
        false
      with
      | Queue.Empty -> false
      | Reached -> true

  end

  let included map r1 r2 : bool = Reachable.is_reachable map r1 r2


  let separated map r1 r2 =
    not (Reachable.is_reachable map r1 r2)
    && not (Reachable.is_reachable map r2 r1)



  (* API ITERATOR *)
  let iter (map:map) (f:node -> unit) : unit =
    Memory.iter_node map.map f


  (* API PRINTER *)
  let pp_node fmt node : unit = Memory.pp_node fmt node




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

  let accesses (m: map) (r:node) : acs =
    let acs_read, acs_write, acs_shift = Memory.accesses m.Code.map r in
    { acs_read ; acs_write ; acs_shift }
end


module Region = struct
  type region = Memory.region


  type map = Code.domain



  (* API GETTERS *)
  let get_map (f:kernel_function) : map = Code.domain f



  let get_id map region = Node.get_id map region.Memory.node
  let get_region map id =
    try Some (Memory.region map.Code.map @@ Node.get_node map id)
    with Not_found -> None



  let cvar (map:map) (var:varinfo) =
    try Some (Memory.region map.Code.map @@ Node.cvar map var)
    with Not_found -> None

  let field (map:map) (region:region) (field:fieldinfo) =
    try Some (Memory.region map.Code.map @@ Node.field map region.Memory.node field)
    with Not_found -> None

  let shift (map:map) region (ty:typ) = (* TODO *)
    try Some (Memory.region map.Code.map @@ Node.shift map region.Memory.node ty)
    with Not_found -> None



  let base_addr _map region = (* TODO *) region



  (* API POINTERS *)
  let points_to (map:map) (region:region) : region option =
    Option.map (Memory.region map.Code.map)
    @@ Memory.cpointed map.map region.Memory.node

  let pointed_by (map:map) (region:region) : region list =
    List.map (Memory.region map.Code.map)
    @@ Memory.cpointed_by map.Code.map region.Memory.node


  (* COMPARATOR *)
  let equal map r1 r2 = Node.equal map r1.Memory.node r2.Memory.node


  module Reachable = struct

    module Imap = Map.Make(Int)

    let is_reachable map source target : bool =
      let q = Queue.create () in
      let exception Reached in
      try
        let push r =
          if equal map target r then raise Reached else Queue.push r q
        in
        push source ;
        let visited = ref Imap.empty in
        while true do (*not !accessible && not @@ Queue.is_empty q do *)
          let region = Queue.pop q in
          if equal map target region then raise Exit else
          if not @@ Imap.mem (get_id map region) !visited then begin
            visited := Imap.add (get_id map region) region !visited ;
            List.iter (fun r -> push (Memory.region map.Code.map r)) region.Memory.parents
          end
        done ;
        false
      with
      | Queue.Empty -> false
      | Reached -> true

  end

  let included map r1 r2 : bool = Reachable.is_reachable map r1 r2


  let separated map r1 r2 =
    not (Reachable.is_reachable map r1 r2)
    && not (Reachable.is_reachable map r2 r1)



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
end
