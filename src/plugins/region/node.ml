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
  nnode : 'a Ufind.rref ;
  nid : int option ;
}
type 'a store = {
  values : 'a Ufind.store ;
  stable_ids : int Ufind.store ;
}

let new_store () = {
  values = Ufind.new_store () ;
  stable_ids = Ufind.new_store () ;
}

let copy s = {
  values = Ufind.copy s.values ;
  stable_ids = s.stable_ids ;
}

let forge n = {
  nnode = Store.forge n ;
  nid = None
}

let get m n = Ufind.get m.values n.nnode
let set m n ?id (v:'a) =
  Ufind.set m.values n.nnode v ;
  match id with
  | None -> ()
  | Some nid -> Ufind.set m.stable_ids (Store.forge @@ Store.id n.nnode) nid

let new_value m v = {
  nnode = Ufind.make m.values v ;
  nid = None ;
}

let key n = Store.id n.nnode
let id n = Option.value ~default:(key n) n.nid

let eq m n1 n2 = Store.eq m.values n1.nnode n2.nnode

let normalize m n =
  let nnode = Ufind.find m.values n.nnode in
  {
    nnode ;
    nid =
      try Some (Ufind.get m.stable_ids @@ Store.forge @@ Store.id nnode)
      with Not_found -> None ;
  }

let compare n1 n2 = Int.compare (Store.id n1.nnode) (Store.id n2.nnode)

let list m ns = List.sort_uniq compare @@ List.map (normalize m) ns

let union m n1 n2 =
  let nnode = Ufind.union m.values n1.nnode n2.nnode in
  let _ = Ufind.union m.stable_ids (Store.forge @@ key n1) (Store.forge @@ key n2) in
  let nid = Option.fold ~none:n2.nid ~some:(fun id -> Some id) n1.nid in
  { nnode ; nid }
