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
  | Cell of int64 * node option
  | Compound of int64 * node Ranges.t

and region = {
  parents: node list ;
  roots: varinfo list ;
  reads: Access.Set.t ;
  writes: Access.Set.t ;
  shifts: Access.Set.t ;
  layout: layout ;
}

type range = node Ranges.range

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

let sizeof_ptr () = Int64.of_int @@ Cil.bitsSizeOf Cil.voidPtrType
let sizeof_typ ty = Int64.of_int @@ Cil.bitsSizeOf ty

let sizeof_layout = function
  | Blob -> Int64.zero | Cell(s,_) | Compound(s,_) -> s

let empty = {
  parents = [] ;
  roots = [] ;
  reads = Access.Set.empty ;
  writes = Access.Set.empty ;
  shifts = Access.Set.empty ;
  layout = Blob ;
}

let cell (m: map) ?size ?ptr () =
  let layout = match size, ptr with
    | None, None -> Blob
    | None, Some _ -> Cell(sizeof_ptr (),ptr)
    | Some s, _ -> Cell(s,ptr)
  in Ufind.make m.store { empty with layout }

(* -------------------------------------------------------------------------- *)
(* --- Map                                                                --- *)
(* -------------------------------------------------------------------------- *)

let node map node =
  try Ufind.find map.store node
  with Not_found -> node

let nodes map ns = Store.list @@ List.map (node map) ns

let region map node =
  try Ufind.get map.store node
  with Not_found -> empty

let root (m: map) v =
  try Vmap.find v m.index with Not_found ->
    let r = cell m () in
    m.index <- Vmap.add v r m.index ; r

(* -------------------------------------------------------------------------- *)
(* --- Merge                                                              --- *)
(* -------------------------------------------------------------------------- *)

type queue = (node * node) Queue.t

let merge_node (m: map) (q: queue) (a: node) (b: node) : node =
  if not @@ Ufind.eq m.store a b then Queue.push (a,b) q ; min a b

let merge_inode (m: map) (q: queue) (a: node) (b: node) : unit =
  ignore @@ merge_node m q a b

let merge_ptr (m: map) (q: queue)
    (pa : node option) (pb : node option) : node option =
  match pa, pb with
  | None, p | p, None -> p
  | Some pa, Some pb -> Some (merge_node m q pa pb)

let merge_range (m: map) (q: queue) (ra : range) (rb : range) : node =
  let na = ra.data in
  let nb = rb.data in
  let ma = Ranges.( ra.offset +. ra.length ) in
  let mb = Ranges.( rb.offset +. rb.length ) in
  let dp = Ranges.( ra.offset -. rb.offset ) in
  let dq = Ranges.( ma -. mb ) in
  let sa = sizeof_layout (region m na).layout in
  let sb = sizeof_layout (region m nb).layout in
  let size = Ranges.(sa %. sb %. dp %. dq) in
  let data = merge_node m q na nb in
  if size = sa && size = sb then data else
    merge_node m q (cell m ~size ()) data

let merge_ranges (m: map) (q: queue)
    (sa : int64) (wa : node Ranges.t)
    (sb : int64) (wb : node Ranges.t)
  : layout =
  if sa = sb then
    Compound(sa, Ranges.merge (merge_range m q) wa wb)
  else
    let size = Ranges.gcd sa sb in
    let r = cell m ~size () in
    Ranges.iter (merge_inode m q r) wa ;
    Ranges.iter (merge_inode m q r) wb ;
    let rg = Ranges.{ offset = Int64.zero ; length = size ; data = r } in
    Compound(size, Ranges.singleton rg )

let merge_layout (m: map) (q: queue) (a : layout) (b : layout) : layout =
  match a, b with
  | Blob, c | c, Blob -> c
  | Cell(sa,pa) , Cell(sb,pb) -> Cell(Ranges.gcd sa sb, merge_ptr m q pa pb)
  | Compound(sa,wa), Compound(sb,wb) -> merge_ranges m q sa wa sb wb
  | Compound(sr,wr), Cell(sx,px)
  | Cell(sx,px), Compound(sr,wr) ->
    let data = cell m ~size:sx ?ptr:px () in
    let wx = Ranges.singleton { offset = Int64.zero ; length = sx ; data } in
    merge_ranges m q sx wx sr wr

let merge_region (m: map) (q: queue) (a : region) (b : region) : region = {
  parents = nodes m (Store.bag a.parents b.parents) ;
  roots = Store.bag a.roots b.roots ;
  reads = Access.Set.union a.reads b.reads ;
  writes = Access.Set.union a.reads b.writes ;
  shifts = Access.Set.union a.reads b.shifts ;
  layout = merge_layout m q a.layout b.layout ;
}

let do_merge (m: map) (q: queue) (a: node) (b: node): unit =
  begin
    let ra = Ufind.get m.store a in
    let rb = Ufind.get m.store b in
    let rx = Ufind.union m.store a b in
    let rc = merge_region m q ra rb in
    Ufind.set m.store rx rc ;
  end

let merge (m: map) (a: node) (b: node) : node =
  if Ufind.eq m.store a b then Ufind.find m.store a else
    let q = Queue.create () in
    do_merge m q a b ;
    while not @@ Queue.is_empty q do
      let a,b = Queue.pop q in
      do_merge m q a b ;
    done ;
    Ufind.find m.store a

(* -------------------------------------------------------------------------- *)
(* --- Access                                                             --- *)
(* -------------------------------------------------------------------------- *)

let points_to (m: map) (a: node) (b: node) =
  ignore @@ merge m a @@ cell m ~ptr:b ()

let read (m: map) (a: node) from =
  let r = region m a in
  Ufind.set m.store a { r with reads = Access.Set.add from r.reads }

let write (m: map) (a: node) from =
  let r = region m a in
  Ufind.set m.store a { r with writes = Access.Set.add from r.writes }

let shift (m: map) (a: node) from =
  let r = region m a in
  Ufind.set m.store a { r with shifts = Access.Set.add from r.shifts }

(* -------------------------------------------------------------------------- *)
