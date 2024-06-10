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

type node = chunk Ufind.rref

and layout =
  | Blob
  | Cell of int * node option
  | Compound of int * node Ranges.t

and chunk = {
  cparents: node list ;
  croots: varinfo list ;
  creads: Access.Set.t ;
  cwrites: Access.Set.t ;
  cshifts: Access.Set.t ;
  clayout: layout ;
}

type rg = node Ranges.range

type map = {
  store: chunk Ufind.store ;
  mutable locked: bool ;
  mutable index: node Vmap.t ;
}

(* -------------------------------------------------------------------------- *)
(* --- Accessors                                                          --- *)
(* -------------------------------------------------------------------------- *)

let sizeof = function Blob -> 0 | Cell(s,_) | Compound(s,_) -> s
let ranges = function Blob | Cell _ -> [] | Compound(_,R rs) -> rs
let pointed = function Blob | Compound _ -> None | Cell(_,p) -> p

let types (m : chunk) : typ list =
  let pool = ref Typ.Set.empty in
  let add acs =
    pool := Typ.Set.add (Cil.unrollType @@ Access.typeof acs) !pool in
  Access.Set.iter add m.creads ;
  Access.Set.iter add m.cwrites ;
  Typ.Set.elements !pool

let failwith_locked m fn =
  if m.locked then raise (Invalid_argument fn)

let lock m = m.locked <- true
let unlock m = m.locked <- false

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
      (fun (rg : rg) ->
         Format.fprintf fmt "@ | %a: %a" Ranges.pp_range rg pp_node rg.data
      ) rg ;
    Format.fprintf fmt "@ }@]"

let pp_chunk fmt (n: node) (m: chunk) =
  begin
    let acs r s = if Access.Set.is_empty s then '-' else r in
    Format.fprintf fmt "@[<hov 2>%a: %c%c%c" pp_node n
      (acs 'R' m.creads) (acs 'W' m.cwrites) (acs 'A' m.cshifts) ;
    List.iter (Format.fprintf fmt "@ (%a)" Typ.pretty) (types m) ;
    List.iter (Format.fprintf fmt "@ %a" Varinfo.pretty) m.croots ;
    if Options.debug_atleast 1 then
      begin
        Access.Set.iter (Format.fprintf fmt "@ R:%a" Access.pretty) m.creads ;
        Access.Set.iter (Format.fprintf fmt "@ W:%a" Access.pretty) m.cwrites ;
        Access.Set.iter (Format.fprintf fmt "@ A:%a" Access.pretty) m.cshifts ;
      end ;
    Format.fprintf fmt "@ %a ;@]" pp_layout m.clayout ;
  end
[@@ warning "-32"]

(* -------------------------------------------------------------------------- *)
(* --- Map Constructors                                                   --- *)
(* -------------------------------------------------------------------------- *)

let create () = {
  locked = false ;
  store = Ufind.new_store () ;
  index = Vmap.empty ;
}

let copy ?locked m = {
  locked = (match locked with None -> m.locked | Some l -> l) ;
  store = Ufind.copy m.store ;
  index = m.index ;
}

let empty = {
  cparents = [] ;
  croots = [] ;
  creads = Access.Set.empty ;
  cwrites = Access.Set.empty ;
  cshifts = Access.Set.empty ;
  clayout = Blob ;
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
(* --- Chunk Constructors                                                 --- *)
(* -------------------------------------------------------------------------- *)

let cell (m: map) ?size ?ptr ?root () =
  failwith_locked m "Region.Memory.cell" ;
  let clayout = match size, ptr with
    | None, None -> Blob
    | None, Some _ -> Cell(Cil.bitsSizeOf Cil.voidPtrType,ptr)
    | Some s, _ -> Cell(s,ptr) in
  let croots = match root with None -> [] | Some v -> [v] in
  Ufind.make m.store { empty with clayout ; croots }

let update (m: map) (n: node) (f: chunk -> chunk) =
  let r = get m n in
  Ufind.set m.store n (f r)

let range (m: map) ~size ~offset ~length ~data : node =
  failwith_locked m "Region.Memory.range" ;
  let last = offset + length in
  if not (0 <= offset && offset < last && last <= size) then
    raise (Invalid_argument "Region.Memory.range") ;
  let clayout = Compound(size, Ranges.singleton { offset ; length ; data }) in
  let n = Ufind.make m.store { empty with clayout } in
  update m data (fun r -> { r with cparents = nodes m @@ n :: r.cparents }) ; n

let root (m: map) v =
  try Vmap.find v m.index with Not_found ->
    failwith_locked m "Region.Memory.root" ;
    let n = cell m ~root:v () in
    m.index <- Vmap.add v n m.index ; n

(* -------------------------------------------------------------------------- *)
(* --- Iterator                                                           --- *)
(* -------------------------------------------------------------------------- *)

type range = {
  offset: int ;
  length: int ;
  cells: int ;
  data: node ;
}

type region = {
  node: node ;
  parents: node list ;
  roots: varinfo list ;
  types: typ list ;
  reads: Access.acs list ;
  writes: Access.acs list ;
  shifts: Access.acs list ;
  sizeof: int ;
  ranges: range list ;
  pointed: node option ;
}

let pp_range fmt (r: range) =
  Format.fprintf fmt "%d..%d [%d]: %a"
    r.offset (r.offset + r.length) r.cells pp_node r.data

let pp_region fmt (m: region) =
  begin
    let acs r s = if s = [] then '-' else r in
    Format.fprintf fmt "@[<hov 2>%a: %c%c%c"
      pp_node m.node
      (acs 'R' m.reads) (acs 'W' m.writes) (acs 'A' m.shifts) ;
    List.iter (Format.fprintf fmt "@ (%a)" Typ.pretty) m.types ;
    List.iter (Format.fprintf fmt "@ %a" Varinfo.pretty) m.roots ;
    Format.fprintf fmt "@ %db" m.sizeof ;
    Option.iter (Format.fprintf fmt "@ (*%a)" pp_node) m.pointed ;
    Format.fprintf fmt "@[<hv 0>]" ;
    List.iter (Format.fprintf fmt "@ %a" pp_range) m.ranges ;
    Format.fprintf fmt "@]" ;
    if Options.debug_atleast 1 then
      begin
        List.iter (Format.fprintf fmt "@ R:%a" Access.pretty) m.reads ;
        List.iter (Format.fprintf fmt "@ W:%a" Access.pretty) m.writes ;
        List.iter (Format.fprintf fmt "@ A:%a" Access.pretty) m.shifts ;
      end ;
    Format.fprintf fmt " ;@]" ;
  end

let make_range (m: map) (rg: rg) : range = {
  offset = rg.offset ;
  length = rg.length ;
  cells = rg.length / sizeof (get m rg.data).clayout ;
  data = node m rg.data ;
}

let make_region (m: map) (n: node) (r: chunk) : region = {
  node = n ;
  parents = nodes m r.cparents ;
  roots = r.croots ;
  reads = Access.Set.elements r.creads ;
  writes = Access.Set.elements r.cwrites ;
  shifts = Access.Set.elements r.cshifts ;
  types = types r ;
  sizeof = sizeof r.clayout ;
  ranges = List.map (make_range m) @@ ranges r.clayout ;
  pointed = Option.map (node m) (pointed r.clayout) ;
}

let region map n = make_region map n (get map n)

let rec walk h m f n =
  let n = Ufind.find m.store n in
  let id = Store.id n in
  try Hashtbl.find h id with Not_found ->
    Hashtbl.add h id () ;
    let r = Ufind.get m.store n in
    f (make_region m n r) ;
    match r.clayout with
    | Blob -> ()
    | Cell(_,p) -> Option.iter (walk h m f) p
    | Compound(_,rg) -> Ranges.iter (walk h m f) rg

let iter (m:map) (f: region -> unit) =
  let h = Hashtbl.create 0 in
  Vmap.iter (fun _x n -> walk h m f n) m.index

let regions map =
  let pool = ref [] in
  iter map (fun r -> pool := r :: !pool) ;
  List.rev !pool

(* -------------------------------------------------------------------------- *)
(* --- Merge                                                              --- *)
(* -------------------------------------------------------------------------- *)

type queue = (node * node) Queue.t

let singleton ~size = function
  | None -> Ranges.empty
  | Some r -> Ranges.range ~length:size r

let merge_node (m: map) (q: queue) (a: node) (b: node) : node =
  if not @@ Ufind.eq m.store a b then Queue.push (a,b) q ;
  Ufind.find m.store (min a b)

let merge_opt (m: map) (q: queue)
    (pa : node option) (pb : node option) : node option =
  match pa, pb with
  | None, p | p, None -> p
  | Some pa, Some pb -> Some (merge_node m q pa pb)

let merge_range (m: map) (q: queue) (ra : rg) (rb : rg) : node =
  let na = ra.data in
  let nb = rb.data in
  let ma = ra.offset + ra.length in
  let mb = rb.offset + rb.length in
  let dp = ra.offset - rb.offset in
  let dq = ma - mb in
  let sa = sizeof (get m na).clayout in
  let sb = sizeof (get m nb).clayout in
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

let merge_region (m: map) (q: queue) (a : chunk) (b : chunk) : chunk = {
  cparents = nodes m @@ Store.bag a.cparents b.cparents ;
  croots = List.sort_uniq Varinfo.compare @@ Store.bag a.croots b.croots ;
  creads = Access.Set.union a.creads b.creads ;
  cwrites = Access.Set.union a.cwrites b.cwrites ;
  cshifts = Access.Set.union a.cshifts b.cshifts ;
  clayout = merge_layout m q a.clayout b.clayout ;
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
  failwith_locked m "Region.Memory.merge" ;
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
  let sr = sizeof (get m a).clayout in
  let size = Ranges.gcd sr (Cil.bitsSizeOf ty) in
  if sr <> size then ignore (merge m a (cell m ~size ()))

let points_to (m: map) (a: node) (b : node) =
  failwith_locked m "Region.Memory.points_to" ;
  ignore @@ merge m a @@ cell m ~ptr:b ()

let read (m: map) (a: node) from =
  failwith_locked m "Region.Memory.read" ;
  let r = get m a in
  Ufind.set m.store a { r with creads = Access.Set.add from r.creads } ;
  access m a (Access.typeof from)

let write (m: map) (a: node) from =
  failwith_locked m "Region.Memory.write" ;
  let r = get m a in
  Ufind.set m.store a { r with cwrites = Access.Set.add from r.cwrites } ;
  access m a (Access.typeof from)

let shift (m: map) (a: node) from =
  failwith_locked m "Region.Memory.shift" ;
  let r = get m a in
  Ufind.set m.store a { r with cshifts = Access.Set.add from r.cshifts }
(* no access *)

(* -------------------------------------------------------------------------- *)
(* --- Lookup                                                            ---- *)
(* -------------------------------------------------------------------------- *)

let cranges m r =
  let rg = Ufind.get m.store r in
  match rg.clayout with
  | Blob | Cell _ -> raise Not_found
  | Compound(s,rgs) -> s, rgs

let cpointed m r =
  let rg = Ufind.get m.store r in
  match rg.clayout with
  | Blob | Compound _ | Cell(_,None) -> None
  | Cell(_,Some r) -> Some (Ufind.find m.store r)

let rec lval (m: map) (lv: lval) : node =
  let h = host m (fst lv) in
  offset m h (snd lv)

and host (m: map) (h: lhost) : node =
  match h with
  | Var x -> Ufind.find m.store @@ Vmap.find x m.index
  | Mem e ->
    match exp m e with
    | None -> raise Not_found
    | Some r -> r

and offset (m: map) (r: node) (ofs: offset) : node =
  match ofs with
  | NoOffset -> Ufind.find m.store r
  | Field (fd, ofs) ->
    let _, rgs = cranges m r in
    let (p,w) = Cil.fieldBitsOffset fd in
    let rg = Ranges.find p rgs in
    if rg.offset <= p && p+w <= rg.offset + rg.length then
      offset m rg.data ofs
    else raise Not_found
  | Index (_, ofs) ->
    let s, rgs = cranges m r in
    match rgs with
    | R [rg] when rg.offset = 0 && rg.length = s ->
      offset m rg.data ofs
    | _ -> raise Not_found

and exp (m: map) (e: exp) : node option =
  match e.enode with
  | Const _
  | SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _ | AlignOfE _ -> None
  | Lval lv -> cpointed m @@ lval m lv
  | AddrOf lv | StartOf lv -> Some (lval m lv)
  | CastE(_, e) -> exp m e
  | BinOp((PlusPI|MinusPI),p,_,_) -> exp m p
  | UnOp (_, _, _) | BinOp (_, _, _, _) -> None

(* -------------------------------------------------------------------------- *)
