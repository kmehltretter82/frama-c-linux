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
open Cil_datatype
module Ufind = UnionFind.Make(Store)
module Vmap = Varinfo.Map

(* -------------------------------------------------------------------------- *)
(* --- Region Maps                                                        --- *)
(* -------------------------------------------------------------------------- *)

[@@@ warning "-37"]

(* All offsets in bits *)

type node = region Ufind.rref

and layout =
  | Blob
  | Atom
  | AtomPtr of node
  | Compound of node Ranges.t

and region = {
  parents: node list ;
  roots: varinfo list ;
  size: int64 ;
  layout: layout ;
}

type map = {
  store: region Ufind.store ;
  mutable index: node Vmap.t ;
}

(* -------------------------------------------------------------------------- *)
(* --- Constructors                                                       --- *)
(* -------------------------------------------------------------------------- *)

let create () = {
  store = Ufind.new_store () ;
  index = Vmap.empty ;
}

let copy m = {
  store = Ufind.copy m.store ;
  index = m.index ;
}

let blob () = {
  parents = [] ;
  roots = [] ;
  size = Int64.zero ;
  layout = Blob ;
}

let node map node =
  try Ufind.find map.store node
  with Not_found -> node

let nodes map ns = Store.list @@ List.map (node map) ns

let region map node =
  try Ufind.get map.store node
  with Not_found -> blob ()

let root (m: map) lv =
  try Vmap.find lv m.index with Not_found ->
    let r = Ufind.make m.store (blob ()) in
    m.index <- Vmap.add lv r m.index ; r

(* -------------------------------------------------------------------------- *)
(* --- Merge                                                              --- *)
(* -------------------------------------------------------------------------- *)

type queue = (node * node) Queue.t

let qmerge (m: map) (q: queue) (a : node) (b : node) : node =
  if not @@ Ufind.eq m.store a b then Queue.push (a,b) q ; min a b

let lmerge (m: map) (q: queue) (r: node) (a : layout) (b : layout) : layout =
  match a, b with
  | Blob, c | c, Blob -> c
  | Atom, c | c, Atom -> c
  | AtomPtr a, AtomPtr b -> AtomPtr (qmerge m q a b)
  | Compound u, Compound v -> Compound (Ranges.merge (qmerge m q) u v)
  | AtomPtr a, Compound w | Compound w, AtomPtr a ->
    Ranges.iter (fun s -> ignore @@ qmerge m q r s) w ; AtomPtr a

let rmerge (m: map) (q: queue) (r: node) (a : region) (b : region) : region = {
  parents = nodes m (Store.bag a.parents b.parents) ;
  roots = Store.bag a.roots b.roots ;
  size = Ranges.gcd a.size b.size ;
  layout = lmerge m q r a.layout b.layout ;
}

let umerge (m: map) (q: queue) (a: node) (b: node): unit =
  begin
    let ra = Ufind.get m.store a in
    let rb = Ufind.get m.store b in
    let r = Ufind.union m.store a b in
    let rc = rmerge m q r ra rb in
    Ufind.set m.store r rc ;
  end

let merge (m: map) (a: node) (b: node) : node =
  if Ufind.eq m.store a b then Ufind.find m.store a else
    let q = Queue.create () in
    umerge m q a b ;
    while not @@ Queue.is_empty q do
      let a,b = Queue.pop q in
      umerge m q a b ;
    done ;
    Ufind.find m.store a

(* -------------------------------------------------------------------------- *)
