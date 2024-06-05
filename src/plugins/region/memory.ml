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

(* All offsets in bits *)

type node = region Ufind.rref

and layout =
  | Blob
  | Cell of int * node option
  | Compound of int * node Ranges.t

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
(* --- Accessors                                                          --- *)
(* -------------------------------------------------------------------------- *)

let sizeof = function Blob -> 0 | Cell(s,_) | Compound(s,_) -> s
let points_to = function Blob | Compound _ -> None | Cell(_,p) -> p
let ranges = function Blob | Cell _ -> [] | Compound(_,R rs) -> rs

let types (m : region) : typ list =
  let pool = ref Typ.Set.empty in
  let add acs =
    pool := Typ.Set.add (Cil.unrollType @@ Access.typeof acs) !pool in
  Access.Set.iter add m.reads ;
  Access.Set.iter add m.writes ;
  Typ.Set.elements !pool

(* -------------------------------------------------------------------------- *)
(* --- Printers                                                           --- *)
(* -------------------------------------------------------------------------- *)

let pp_node fmt (n : node) = Format.fprintf fmt "R%04x" @@ Store.id n

let pp_layout fmt = function
  | Blob -> Format.pp_print_string fmt "<blob>"
  | Cell(s,None) -> Format.fprintf fmt "<%04d>" s
  | Cell(s,Some n) -> Format.fprintf fmt "<%04d>(*%a)" s pp_node n
  | Compound(s,rg) ->
    Format.fprintf fmt "@[<hv 0>{%04d" s ;
    Ranges.iteri
      (fun (rg : range) ->
         Format.fprintf fmt "@ | %a: %a" Ranges.pp_range rg pp_node rg.data
      ) rg ;
    Format.fprintf fmt "@ }@]"

let pp_region fmt (n: node) (m: region) =
  begin
    let acs r s = if Access.Set.is_empty s then '-' else r in
    Format.fprintf fmt "@[<hov 2>%a: %c%c%c" pp_node n
      (acs 'R' m.reads) (acs 'W' m.writes) (acs 'A' m.shifts) ;
    List.iter (Format.fprintf fmt "@ (%a)" Typ.pretty) (types m) ;
    List.iter (Format.fprintf fmt "@ %a" Varinfo.pretty) m.roots ;
    if Options.debug_atleast 1 then
      begin
        Access.Set.iter (Format.fprintf fmt "@ R:%a" Access.pretty) m.reads ;
        Access.Set.iter (Format.fprintf fmt "@ W:%a" Access.pretty) m.writes ;
        Access.Set.iter (Format.fprintf fmt "@ A:%a" Access.pretty) m.shifts ;
      end ;
    Format.fprintf fmt "@ %a ;@]" pp_layout m.layout ;
  end

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

let empty = {
  parents = [] ;
  roots = [] ;
  reads = Access.Set.empty ;
  writes = Access.Set.empty ;
  shifts = Access.Set.empty ;
  layout = Blob ;
}

(* -------------------------------------------------------------------------- *)
(* --- Map                                                                --- *)
(* -------------------------------------------------------------------------- *)

let id = Store.id
let forge = Store.forge

let node map node =
  try Ufind.find map.store node
  with Not_found -> node

let nodes map ns = Store.list @@ List.map (node map) ns

let get map node =
  try Ufind.get map.store node
  with Not_found -> empty

(* -------------------------------------------------------------------------- *)
(* --- Constructors                                                       --- *)
(* -------------------------------------------------------------------------- *)

let cell (m: map) ?size ?ptr ?root () =
  let layout = match size, ptr with
    | None, None -> Blob
    | None, Some _ -> Cell(Cil.bitsSizeOf Cil.voidPtrType,ptr)
    | Some s, _ -> Cell(s,ptr) in
  let roots = match root with None -> [] | Some v -> [v] in
  Ufind.make m.store { empty with layout ; roots }

let update (m: map) (n: node) (f: region -> region) =
  let r = get m n in
  Ufind.set m.store n (f r)

let range (m: map) ~size ~offset ~length ~data : node =
  let last = offset + length in
  if not (0 <= offset && offset < last && last <= size) then
    raise (Invalid_argument "Region.Memory.range") ;
  let layout = Compound(size, Ranges.singleton { offset ; length ; data }) in
  let n = Ufind.make m.store { empty with layout } in
  update m data (fun r -> { r with parents = nodes m @@ n :: r.parents }) ; n

let root (m: map) v =
  try Vmap.find v m.index with Not_found ->
    let n = cell m ~root:v () in
    m.index <- Vmap.add v n m.index ; n

(* -------------------------------------------------------------------------- *)
(* --- Iterator                                                           --- *)
(* -------------------------------------------------------------------------- *)

let normalize map r = {
  parents = nodes map r.parents ;
  roots = r.roots ;
  reads = r.reads ;
  writes = r.writes ;
  shifts = r.shifts ;
  layout =
    match r.layout with
    | Blob -> Blob
    | Cell(s,p) -> Cell(s,Option.map (node map) p)
    | Compound(s,rg) -> Compound(s,Ranges.map (node map) rg)
}

let region map n = normalize map (get map n)

let rec walk h m f n =
  let n = Ufind.find m.store n in
  let id = Store.id n in
  try Hashtbl.find h id with Not_found ->
    Hashtbl.add h id () ;
    let r = Ufind.get m.store n in
    f n (normalize m r) ;
    match r.layout with
    | Blob -> ()
    | Cell(_,p) -> Option.iter (walk h m f) p
    | Compound(_,rg) -> Ranges.iter (walk h m f) rg

let iter (m:map) (f: node -> region -> unit) =
  let h = Hashtbl.create 0 in
  Vmap.iter (fun _ n -> walk h m f n) m.index

(* -------------------------------------------------------------------------- *)
(* --- Merge                                                              --- *)
(* -------------------------------------------------------------------------- *)

type queue = (node * node) Queue.t

let singleton ~size = function
  | None -> Ranges.empty
  | Some r -> Ranges.range ~length:size r

let merge_node (m: map) (q: queue) (a: node) (b: node) : node =
  if not @@ Ufind.eq m.store a b then Queue.push (a,b) q ; min a b

let merge_opt (m: map) (q: queue)
    (pa : node option) (pb : node option) : node option =
  match pa, pb with
  | None, p | p, None -> p
  | Some pa, Some pb -> Some (merge_node m q pa pb)

let merge_range (m: map) (q: queue) (ra : range) (rb : range) : node =
  let na = ra.data in
  let nb = rb.data in
  let ma = ra.offset + ra.length in
  let mb = rb.offset + rb.length in
  let dp = ra.offset - rb.offset in
  let dq = ma - mb in
  let sa = sizeof (get m na).layout in
  let sb = sizeof (get m nb).layout in
  let size = Ranges.(sa %. sb %. dp %. dq) in
  let data = merge_node m q na nb in
  if size = sa && size = sb then data else
    merge_node m q (cell m ~size ()) data

let merge_ranges (m: map) (q: queue)
    (sa : int) (wa : node Ranges.t)
    (sb : int) (wb : node Ranges.t)
  : layout =
  if sa = sb then
    Compound(sa, Ranges.merge (merge_range m q) wa wb)
  else
    let size = Ranges.gcd sa sb in
    let ra = Ranges.squash (merge_node m q) wa in
    let rb = Ranges.squash (merge_node m q) wb in
    Compound(size, singleton ~size @@ merge_opt m q ra rb)

let merge_layout (m: map) (q: queue) (a : layout) (b : layout) : layout =
  match a, b with
  | Blob, c | c, Blob -> c

  | Cell(sa,pa) , Cell(sb,pb) -> Cell(Ranges.gcd sa sb, merge_opt m q pa pb)

  | Compound(sa,wa), Compound(sb,wb) -> merge_ranges m q sa wa sb wb

  | Compound(sr,wr), Cell(sx,None) | Cell(sx,None), Compound(sr,wr) ->
    let size = Ranges.gcd sx sr in
    Compound(size, singleton ~size @@ Ranges.squash (merge_node m q) wr)

  | Compound(sr,wr), Cell(sx,Some ptr) | Cell(sx,Some ptr), Compound(sr,wr) ->
    let rp = cell m ~size:sx ~ptr () in
    let wx = Ranges.range ~length:sx rp in
    merge_ranges m q sx wx sr wr

let merge_region (m: map) (q: queue) (a : region) (b : region) : region = {
  parents = nodes m (Store.bag a.parents b.parents) ;
  roots = Store.bag a.roots b.roots ;
  reads = Access.Set.union a.reads b.reads ;
  writes = Access.Set.union a.writes b.writes ;
  shifts = Access.Set.union a.shifts b.shifts ;
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

let access (m:map) (a:node) (ty: typ) =
  let sr = sizeof (get m a).layout in
  let size = Ranges.gcd sr (Cil.bitsSizeOf ty) in
  if sr <> size then ignore (merge m a (cell m ~size ()))

let pointer (m: map) (a: node) (b : node) =
  ignore @@ merge m a @@ cell m ~ptr:b ()

let read (m: map) (a: node) from =
  let r = get m a in
  Ufind.set m.store a { r with reads = Access.Set.add from r.reads } ;
  access m a (Access.typeof from)

let write (m: map) (a: node) from =
  let r = get m a in
  Ufind.set m.store a { r with writes = Access.Set.add from r.writes } ;
  access m a (Access.typeof from)

let shift (m: map) (a: node) from =
  let r = get m a in
  Ufind.set m.store a { r with shifts = Access.Set.add from r.shifts }
(* no access *)

(* -------------------------------------------------------------------------- *)
