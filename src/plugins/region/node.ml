(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

module Imap = Map.Make(Int)
module Ufind = UnionFind.Make(Store)

type 'a t = {
  nnode : ('a * int option) Ufind.rref ;
  nid : int option ;
}

type 'a store = {
  values : ('a * int option) Ufind.store ;
  mutable ids_to_rref : int Imap.t ;
}

let new_store () = {
  values = Ufind.new_store () ;
  ids_to_rref = Imap.empty ;
}

let copy s = {
  values = Ufind.copy s.values ;
  ids_to_rref = s.ids_to_rref ;
}

let key n = Store.id n.nnode

let id n = n.nid

let forge n = {
  nnode = Store.forge n ;
  nid = None
}

let get m n = fst @@ Ufind.get m.values n.nnode

let set m n (v:'a) =
  Ufind.set m.values n.nnode (v,None)

let set_id m n nid =
  Ufind.set m.values n.nnode (fst @@ Ufind.get m.values n.nnode, Some nid) ;
  m.ids_to_rref <- Imap.add nid (key n) m.ids_to_rref

let new_value m v = {
  nnode = Ufind.make m.values (v,None) ;
  nid = None ;
}

let eq m n1 n2 = Store.eq m.values n1.nnode n2.nnode

let normalize m n =
  let nnode = Ufind.find m.values n.nnode in
  {
    nnode ;
    nid = snd @@ Ufind.get m.values nnode ;
  }

let id_to_node m id =
  normalize m {
    nnode = Store.forge @@ Imap.find id m.ids_to_rref ;
    nid = Some id ;
  }

let compare n1 n2 = Int.compare (key n1) (key n2)

let list m ns = List.sort_uniq compare @@ List.map (normalize m) ns

let union m n1 n2 =
  let nnode = Ufind.union m.values n1.nnode n2.nnode in
  let nid = try snd @@ Ufind.get m.values nnode with Not_found -> None in
  { nnode ; nid }

let pp_ids fmt m =
  Imap.iter (fun i n -> Format.fprintf fmt "; %i=%i ;" i n) m.ids_to_rref
