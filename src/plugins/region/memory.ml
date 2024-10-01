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
module Vset = Varinfo.Set
module Lmap = Map.Make(String)
module Lset = Set.Make(String)

(* -------------------------------------------------------------------------- *)
(* --- Region Maps                                                        --- *)
(* -------------------------------------------------------------------------- *)

(* All offsets in bits *)

type node = chunk Ufind.rref

and layout =
  | Blob
  | Cell of int * node option
  | Compound of int * Fields.domain * node Ranges.t

and chunk = {
  cparents: node list ;
  cpointed: node list ;
  croots: Vset.t ;
  clabels: Lset.t ;
  creads: Access.Set.t ;
  cwrites: Access.Set.t ;
  cshifts: Access.Set.t ;
  clayout: layout ;
}

type rg = node Ranges.range

type map = {
  store: chunk Ufind.store ;
  mutable locked: bool ;
  mutable roots: node Vmap.t ;
  mutable labels: node Lmap.t ;
}

(* -------------------------------------------------------------------------- *)
(* --- Accessors                                                          --- *)
(* -------------------------------------------------------------------------- *)

let sizeof = function Blob -> 0 | Cell(s,_) | Compound(s,_,_) -> s
let ranges = function Blob | Cell _ -> [] | Compound(_,_,R rs) -> rs
let fields = function Blob | Cell _ -> Fields.empty | Compound(_,fds,_) -> fds
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

let pp_field fields fmt fd =
  if Options.debug_atleast 1 then Ranges.pp_range fmt fd else
    Fields.pretty fields fmt fd

let pp_layout fmt = function
  | Blob -> Format.pp_print_string fmt "<blob>"
  | Cell(s,None) -> Format.fprintf fmt "<%04d>" s
  | Cell(s,Some n) -> Format.fprintf fmt "<%04d>(*%a)" s pp_node n
  | Compound(s,fields,rg) ->
    Format.fprintf fmt "@[<hv 0>{%04d" s ;
    Ranges.iteri
      (fun (rg : rg) ->
         Format.fprintf fmt "@ | %a: %a" (pp_field fields) rg pp_node rg.data
      ) rg ;
    Format.fprintf fmt "@ }@]"

let pp_chunk fmt (n: node) (m: chunk) =
  begin
    let acs r s = if Access.Set.is_empty s then '-' else r in
    Format.fprintf fmt "@[<hov 2>%a: %c%c%c" pp_node n
      (acs 'R' m.creads) (acs 'W' m.cwrites) (acs 'A' m.cshifts) ;
    List.iter (Format.fprintf fmt "@ (%a)" Typ.pretty) (types m) ;
    Lset.iter (Format.fprintf fmt "@ %s:") m.clabels ;
    Vset.iter (Format.fprintf fmt "@ %a" Varinfo.pretty) m.croots ;
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
  roots = Vmap.empty ;
  labels = Lmap.empty ;
}

let copy ?locked m = {
  locked = (match locked with None -> m.locked | Some l -> l) ;
  store = Ufind.copy m.store ;
  roots = m.roots ;
  labels = m.labels ;
}

let empty = {
  cparents = [] ;
  cpointed = [] ;
  croots = Vset.empty ;
  clabels = Lset.empty ;
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
let equal (m: map) = Ufind.eq m.store

let node map node =
  try Ufind.find map.store node
  with Not_found -> node

let nodes map ns = Store.list @@ List.map (node map) ns

let get map node =
  try Ufind.get map.store node
  with Not_found -> empty

let update (m: map) (n: node) (f: chunk -> chunk) =
  let r = get m n in
  Ufind.set m.store n (f r)

(* -------------------------------------------------------------------------- *)
(* --- Chunk Constructors                                                 --- *)
(* -------------------------------------------------------------------------- *)

let new_chunk (m: map) ?(size=0) ?ptr ?pointed () =
  failwith_locked m "Region.Memory.new_chunk" ;
  let clayout =
    match ptr with
    | None -> if size = 0 then Blob else Cell(size,None)
    | Some _ -> Cell(Ranges.gcd size (Cil.bitsSizeOf Cil_const.voidPtrType), ptr)
  in
  let cpointed =
    match pointed with
    | None -> []
    | Some ptr -> [ptr]
  in
  Ufind.make m.store { empty with clayout ; cpointed }

let new_range (m: map) ?(fields=Fields.empty) ~size ~offset ~length data : node =
  failwith_locked m "Region.Memory.new_range" ;
  let last = offset + length in
  if not (0 <= offset && offset < last && last <= size) then
    raise (Invalid_argument "Region.Memory.add_range") ;
  let ranges = Ranges.singleton { offset ; length ; data } in
  let clayout = Compound(size, fields, ranges) in
  let n = Ufind.make m.store { empty with clayout } in
  update m data (fun r -> { r with cparents = nodes m @@ n :: r.cparents }) ; n

let add_root (m: map) v =
  try Vmap.find v m.roots with Not_found ->
    failwith_locked m "Region.Memory.add_root" ;
    let n = new_chunk m () in
    update m n (fun d -> { d with croots = Vset.singleton v }) ;
    m.roots <- Vmap.add v n m.roots ; n

let add_label (m: map) a =
  try Lmap.find a m.labels with Not_found ->
    failwith_locked m "Region.Memory.add_label" ;
    let n = new_chunk m () in
    update m n (fun d -> { d with clabels = Lset.singleton a }) ;
    m.labels <- Lmap.add a n m.labels ; n

(* -------------------------------------------------------------------------- *)
(* --- Iterator                                                           --- *)
(* -------------------------------------------------------------------------- *)

type range = {
  label: string ; (* pretty printed fields *)
  offset: int ;
  length: int ;
  cells: int ;
  data: node ;
}

type region = {
  node: node ;
  parents: node list ;
  roots: varinfo list ;
  labels: string list ;
  types: typ list ;
  fields: Fields.domain ;
  reads: Access.acs list ;
  writes: Access.acs list ;
  shifts: Access.acs list ;
  sizeof: int ;
  ranges: range list ;
  pointed: node option ;
}

let pp_cells fmt = function
  | 1 -> ()
  | 0 -> Format.fprintf fmt "[…]"
  | n -> Format.fprintf fmt "[%d]" n

type slice =
  | Padding of int
  | Range of range

let pad p q s =
  let n = q - p in
  if n > 0 then Padding n :: s else s

let rec span k s = function
  | [] -> pad k s []
  | r::rs -> pad k r.offset @@ Range r :: span (r.offset + r.length) s rs

let pp_slice fields fmt = function
  | Padding n ->
    Format.fprintf fmt "@ %a;" Fields.pp_bits n
  | Range r ->
    Format.fprintf fmt "@ %t: %a%a;"
      (Fields.pslice ~fields ~offset:r.offset ~length:r.length)
      pp_node r.data
      pp_cells r.cells

let pp_range fmt (r: range) =
  Format.fprintf fmt "@ %d..%d: %a%a;"
    r.offset (r.offset + r.length) pp_node r.data pp_cells r.cells

let pp_region fmt (m: region) =
  begin
    let acs r s = if s = [] then '-' else r in
    Format.fprintf fmt "@[<hov 2>%a: %c%c%c"
      pp_node m.node
      (acs 'R' m.reads) (acs 'W' m.writes) (acs 'A' m.shifts) ;
    List.iter (Format.fprintf fmt "@ %s:") m.labels ;
    List.iter (Format.fprintf fmt "@ %a" Varinfo.pretty) m.roots ;
    List.iter (Format.fprintf fmt "@ (%a)" Typ.pretty) m.types ;
    Format.fprintf fmt "@ %db" m.sizeof ;
    Option.iter (Format.fprintf fmt "@ (*%a)" pp_node) m.pointed ;
    if m.ranges <> [] then
      begin
        Format.fprintf fmt "@ @[<hv 0>@[<hv 2>{" ;
        if Options.debug_atleast 1 then
          List.iter (pp_range fmt) m.ranges
        else
          List.iter (pp_slice m.fields fmt) (span 0 m.sizeof m.ranges) ;
        Format.fprintf fmt "@]@ }@]" ;
      end ;
    if Options.debug_atleast 1 then
      begin
        List.iter (Format.fprintf fmt "@ R:%a" Access.pretty) m.reads ;
        List.iter (Format.fprintf fmt "@ W:%a" Access.pretty) m.writes ;
        List.iter (Format.fprintf fmt "@ A:%a" Access.pretty) m.shifts ;
      end ;
    Format.fprintf fmt " ;@]" ;
  end

let make_range (m: map) fields Ranges.{ length ; offset ; data } : range =
  let s = sizeof (get m data).clayout in
  let p = Fields.pslice ~fields ~offset ~length in
  {
    label = Format.asprintf "%t" p ;
    offset ; length ;
    cells = if s = 0 then 0 else length / s ;
    data = node m data ;
  }

let make_region (m: map) (n: node) (r: chunk) : region =
  let fields = fields r.clayout in
  {
    node = n ;
    parents = nodes m r.cparents ;
    roots = Vset.elements r.croots ;
    labels = Lset.elements r.clabels ;
    reads = Access.Set.elements r.creads ;
    writes = Access.Set.elements r.cwrites ;
    shifts = Access.Set.elements r.cshifts ;
    types = types r ;
    sizeof = sizeof r.clayout ;
    fields ; ranges = List.map (make_range m fields) @@ ranges r.clayout ;
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
    | Compound(_,_,rg) -> Ranges.iter (walk h m f) rg

let iter (m:map) (f: region -> unit) =
  let h = Hashtbl.create 0 in
  Vmap.iter (fun _x n -> walk h m f n) m.roots

let rec walk_node h m (f: node -> unit) n =
  let n = Ufind.find m.store n in
  let id = Store.id n in
  try Hashtbl.find h id with Not_found ->
    Hashtbl.add h id () ;
    f n ;
    let r = Ufind.get m.store n in
    match r.clayout with
    | Blob -> ()
    | Cell(_,p) -> Option.iter (walk_node h m f) p
    | Compound(_,_,rg) -> Ranges.iter (walk_node h m f) rg

let iter_node (m:map) (f: node -> unit) =
  let h = Hashtbl.create 0 in
  Vmap.iter (fun _x n -> walk_node h m f n) m.roots

let regions map =
  let pool = ref [] in
  iter map (fun r -> pool := r :: !pool) ;
  List.rev !pool


let parents (m: map) (r: node) =
  let chunk = Ufind.get m.store r in
  nodes m chunk.cparents

let roots (m: map) (r: node) =
  let chunk = Ufind.get m.store r in Vset.elements chunk.croots

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
    merge_node m q (new_chunk m ~size ()) data

let merge_ranges (m: map) (q: queue)
    (sa : int) (fa : Fields.domain) (wa : node Ranges.t)
    (sb : int) (fb : Fields.domain) (wb : node Ranges.t)
  : layout =
  let fields = Fields.union fa fb in
  if sa = sb then
    Compound(sa, fields, Ranges.merge (merge_range m q) wa wb)
  else
    let size = Ranges.gcd sa sb in
    let ra = Ranges.squash (merge_node m q) wa in
    let rb = Ranges.squash (merge_node m q) wb in
    Compound(size, fields, singleton ~size @@ merge_opt m q ra rb)

let merge_layout (m: map) (q: queue) (a : layout) (b : layout) : layout =
  match a, b with
  | Blob, c | c, Blob -> c

  | Cell(sa,pa) , Cell(sb,pb) -> Cell(Ranges.gcd sa sb, merge_opt m q pa pb)

  | Compound(sa,fa,wa), Compound(sb,fb,wb) ->
    merge_ranges m q sa fa wa sb fb wb

  | Compound(sr,fr,wr), Cell(sx,None)
  | Cell(sx,None), Compound(sr,fr,wr) ->
    let size = Ranges.gcd sx sr in
    Compound(size, fr, singleton ~size @@ Ranges.squash (merge_node m q) wr)

  | Compound(sr,fr,wr), Cell(sx,Some ptr)
  | Cell(sx,Some ptr), Compound(sr,fr,wr) ->
    let rp = new_chunk m ~size:sx ~ptr () in
    let fx = Fields.empty in
    let wx = Ranges.range ~length:sx rp in
    merge_ranges m q sx fx wx sr fr wr

let merge_region (m: map) (q: queue) (a : chunk) (b : chunk) : chunk = {
  cparents = nodes m @@ Store.bag a.cparents b.cparents ;
  cpointed = nodes m @@ Store.bag a.cpointed b.cpointed ;
  clabels = Lset.union a.clabels b.clabels ;
  croots = Vset.union a.croots b.croots ;
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

let merge_all (m:map) = function
  | [] -> ()
  | r::rs ->
    let q = Queue.create () in
    List.iter (fun r' -> ignore @@ merge_node m q r r') rs ;
    while not @@ Queue.is_empty q do
      let a,b = Queue.pop q in
      do_merge m q a b ;
    done

let merge (m: map) (a: node) (b: node) : unit =
  failwith_locked m "Region.Memory.merge" ;
  merge_all m [a;b]

let merge_copy (m: map) ~(l: node) ~(r: node) : unit =
  let { clayout } = get m r in
  merge_all m [ l; Ufind.make m.store { empty with clayout } ]

(* -------------------------------------------------------------------------- *)
(* --- Offset                                                             --- *)
(* -------------------------------------------------------------------------- *)

let add_field (m:map) (r:node) (fd:fieldinfo) : node =
  let ci = fd.fcomp in
  if ci.cstruct then
    let size = Cil.bitsSizeOf (TComp(ci,[])) in
    let offset, length = Cil.fieldBitsOffset fd in
    let rf = new_chunk m () in
    let fields = Fields.singleton fd in
    let rc = new_range m ~fields ~size ~offset ~length rf in
    ignore @@ merge m r rc ; rf
  else r

let add_index (m:map) (r:node) (ty:typ) (n:int) : node =
  let s = Cil.bitsSizeOf ty * n in
  let re = new_chunk m () in
  let rc = new_range m ~size:s ~offset:0 ~length:s re in
  ignore @@ merge m r rc ; re

let add_points_to (m: map) (a: node) (b : node) =
  begin
    failwith_locked m "Region.Memory.points_to" ;
    ignore @@ merge m a @@ new_chunk m ~ptr:b () ;
    ignore @@ merge m b @@ new_chunk m ~pointed:a () ;
  end

let add_value (m:map) (rv:node) (ty:typ) : node option =
  if Cil.isPointerType ty then
    begin
      failwith_locked m "Region.Memory.add_value" ;
      let rp = new_chunk m ~pointed:rv () in
      ignore @@ merge m rv @@ new_chunk m ~ptr:rp () ;
      Some rp
    end
  else
    None

(* -------------------------------------------------------------------------- *)
(* --- Access                                                             --- *)
(* -------------------------------------------------------------------------- *)

let sized (m:map) (a:node) (ty: typ) =
  let sr = sizeof (get m a).clayout in
  let size = Ranges.gcd sr (Cil.bitsSizeOf ty) in
  if sr <> size then ignore (merge m a (new_chunk m ~size ()))

let read (m: map) (a: node) from =
  failwith_locked m "Region.Memory.read" ;
  let r = get m a in
  Ufind.set m.store a { r with creads = Access.Set.add from r.creads } ;
  sized m a (Access.typeof from)

let write (m: map) (a: node) from =
  failwith_locked m "Region.Memory.write" ;
  let r = get m a in
  Ufind.set m.store a { r with cwrites = Access.Set.add from r.cwrites } ;
  sized m a (Access.typeof from)

let shift (m: map) (a: node) from =
  failwith_locked m "Region.Memory.shift" ;
  let r = get m a in
  Ufind.set m.store a { r with cshifts = Access.Set.add from r.cshifts } ;
  sized m a (Access.typeof from)

(* -------------------------------------------------------------------------- *)
(* --- Lookup                                                            ---- *)
(* -------------------------------------------------------------------------- *)

let points_to m (r : node) : node option =
  let rg = Ufind.get m.store r in
  match rg.clayout with
  | Blob | Compound _ | Cell(_,None) -> None
  | Cell(_,Some r) -> Some (Ufind.find m.store r)

let pointed_by m (r : node) =
  let rg = Ufind.get m.store r in rg.cpointed

let cvar (m: map) (v: varinfo) : node =
  Ufind.find m.store @@ Vmap.find v m.roots

let rec move (m: map) (r: node) (p: int) (s: int) =
  let c = Ufind.get m.store r in
  match c.clayout with
  | Blob | Cell _ -> r
  | Compound(s0,_,rgs) ->
    if s0 <= s then r else
      let rg = Ranges.find p rgs in
      move m rg.data (p - rg.offset) s

let field (m: map) (r: node) (fd: fieldinfo) : node =
  let s = Cil.bitsSizeOf fd.ftype in
  let (p,_) = Cil.fieldBitsOffset fd in
  move m r p s

let index (m : map) (r: node) (ty:typ) : node =
  move m r 0 (Cil.bitsSizeOf ty)

let rec lval (m: map) (h,ofs) : node =
  offset m (lhost m h) (Cil.typeOfLhost h) ofs

and lhost (m: map) (h: lhost) : node =
  match h with
  | Var x -> cvar m x
  | Mem e ->
    match exp m e with
    | Some r -> r
    | None -> raise Not_found

and offset (m: map) (r: node) (ty: typ) (ofs: offset) : node =
  match ofs with
  | NoOffset -> Ufind.find m.store r
  | Field (fd, ofs) ->
    offset m (field m r fd) fd.ftype ofs
  | Index (_, ofs) ->
    let te = Cil.typeOf_array_elem ty in
    offset m (index m r te) te ofs

and exp (m: map) (e: exp) : node option =
  match e.enode with
  | Const _
  | SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _ | AlignOfE _ -> None
  | Lval lv -> points_to m @@ lval m lv
  | AddrOf lv | StartOf lv -> Some (lval m lv)
  | CastE(_, e) -> exp m e
  | BinOp((PlusPI|MinusPI),p,_,_) -> exp m p
  | UnOp (_, _, _) | BinOp (_, _, _, _) -> None

(* -------------------------------------------------------------------------- *)

let included map source target : bool =
  let exception Reached in
  try
    let q = Queue.create () in (* only marked nodes *)
    let push r =
      let r = node map r in
      if equal map target r then raise Reached else Queue.push r q
    in
    push source ;
    let visited = Hashtbl.create 0 in
    while true do
      let node = Queue.pop q in
      if equal map target node then raise Exit else
        let id = id node in
        if not @@ Hashtbl.mem visited id then
          begin
            Hashtbl.add visited id () ;
            List.iter push (parents map node) ;
          end
    done ;
    assert false
  with
  | Queue.Empty -> false
  | Reached -> true

let separated map r1 r2 =
  not (included map r1 r2) && not (included map r2 r1)

(* -------------------------------------------------------------------------- *)

let reads (m : map) (r:node) =
  let node = Ufind.get m.store r in
  List.map Access.typeof @@ Access.Set.elements node.creads

let writes (m : map) (r:node) =
  let node = Ufind.get m.store r in
  List.map Access.typeof @@ Access.Set.elements node.cwrites

let shifts (m : map) (r:node) =
  let node = Ufind.get m.store r in
  List.map Access.typeof @@ Access.Set.elements node.cshifts
