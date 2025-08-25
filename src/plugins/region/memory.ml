(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype
module Vmap = Varinfo.Map
module Vset = Varinfo.Set
module Lmap = Map.Make(String)
module Lset = Set.Make(String)
module LVmap = Logic_var.Map
module LVImap = Logic_info.Map
(* -------------------------------------------------------------------------- *)
(* --- Region Maps                                                        --- *)
(* -------------------------------------------------------------------------- *)

type 'a nlayout =
  | Blob
  | Cell of int * 'a option
  | Compound of int * Fields.domain * 'a Ranges.t
  (* must only contain strict sub-ranges *)

and 'a nchunk = {
  cparents: 'a list ;
  cpointed: 'a list ;
  ccvars: Vset.t ;
  clabels: Lset.t ;
  creads: Access.Set.t ;
  cwrites: Access.Set.t ;
  cshifts: Access.Set.t ;
  clayout: 'a nlayout ;
  mutable cid : int ;
}

(* All offsets in bits *)

module N = Store.Make(struct
    type 'a t = 'a nchunk
    let get_id c = c.cid
    let set_id c cid = c.cid <- cid ; c
  end)

type node = Node of node N.t
type chunk = node nchunk
type layout = node nlayout
type rg = node Ranges.range

type domain = node Ldomain.t
type context = node Ldomain.context

type map = {
  store: node N.store ;
  mutable labels: node Lmap.t ;
  mutable locked: bool ;
  mutable cvars: node Vmap.t ;
  mutable lvars: domain LVmap.t ;
  mutable logics: domain LVImap.t ;
  mutable result: node option ;
}

(* -------------------------------------------------------------------------- *)
(* --- Accessors                                                          --- *)
(* -------------------------------------------------------------------------- *)

let bitsSizeOf ty =
  try Cil.bitsSizeOf ty with
  | Cil.SizeOfError (_, { tnode = TFun _ }) -> Machine.sizeof_fun () * 8
  | Cil.SizeOfError (_, { tnode = TVoid  }) -> Machine.sizeof_void () * 8

let sizeof = function Blob -> 0 | Cell(s,_) | Compound(s,_,_) -> s
let cranges = function Blob | Cell _ -> [] | Compound(_,_,R rs) -> rs
let cfields = function Blob | Cell _ -> Fields.empty | Compound(_,fds,_) -> fds
let cpointed = function Blob | Compound _ -> None | Cell(_,p) -> p

let ctypes (m : chunk) : typ list =
  let pool = ref Typ.Set.empty in
  let add acs =
    pool := Typ.Set.add (Ast_types.unroll @@ Access.typeof acs) !pool in
  Access.Set.iter add m.creads ;
  Access.Set.iter add m.cwrites ;
  Typ.Set.elements !pool

(* -------------------------------------------------------------------------- *)
(* --- Map Constructors                                                   --- *)
(* -------------------------------------------------------------------------- *)

let create () = {
  locked = false ;
  store = N.new_store () ;
  cvars = Vmap.empty ;
  labels = Lmap.empty ;
  lvars = LVmap.empty ;
  logics = LVImap.empty ;
  result = None;
}

let copy ?locked m = {
  locked = (match locked with None -> m.locked | Some l -> l) ;
  store = N.copy m.store ;
  cvars = m.cvars ;
  labels = m.labels ;
  lvars = m.lvars ;
  logics = m.logics ;
  result = m.result ;
}

let empty = {
  cparents = [] ;
  cpointed = [] ;
  ccvars = Vset.empty ;
  clabels = Lset.empty ;
  creads = Access.Set.empty ;
  cwrites = Access.Set.empty ;
  cshifts = Access.Set.empty ;
  clayout = Blob ;
  cid = (-1) ;
}

(* -------------------------------------------------------------------------- *)
(* --- Map                                                                --- *)
(* -------------------------------------------------------------------------- *)

let make_node n = Node n
let get_node = function Node n -> n

let forge m n = make_node @@ N.forge m.store n

let id_to_node m id = forge m id

let equal n1 n2 = N.eq (get_node n1) (get_node n2)

let normalize node = make_node @@ N.normalize @@ get_node node

let id n = N.key @@ get_node n

let uid n = N.id @@ N.normalize @@ get_node n

let nodes l = List.map make_node @@ N.list @@ List.map get_node l

let get node = try N.get @@ get_node node with Not_found -> empty

let update (n: node) (f: chunk -> chunk) =
  let r = get n in
  let c = f r in
  N.set (get_node n) c

let failwith_locked m fn =
  if m.locked then raise (Invalid_argument (fn ^ ": locked"))

(* -------------------------------------------------------------------------- *)
(* --- Printers                                                           --- *)
(* -------------------------------------------------------------------------- *)

let pp_node fmt (n : node) =
  try Format.fprintf fmt "R%04x" (N.id (get_node n))
  with Not_found -> Format.fprintf fmt "r%04x" (N.key (get_node n))

let pp_field fields fmt fd =
  if Options.debug_atleast 1 then Ranges.pp_range fmt fd else
    Fields.pretty fields fmt fd

let pp_layout fmt =
  function
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

let pp_chunk name fmt (m: chunk) =
  begin
    let acs r s = if Access.Set.is_empty s then '-' else r in
    Format.fprintf fmt "@[<hov 2>%s: %c%c%c" name
      (acs 'R' m.creads) (acs 'W' m.cwrites) (acs 'A' m.cshifts) ;
    List.iter (Format.fprintf fmt "@ (%a)" Typ.pretty) (ctypes m) ;
    Lset.iter (Format.fprintf fmt "@ %s:") m.clabels ;
    Vset.iter (Format.fprintf fmt "@ %a" Varinfo.pretty) m.ccvars ;
    if Options.debug_atleast 1 then
      begin
        Access.Set.iter (Format.fprintf fmt "@ R:%a" Access.pretty) m.creads ;
        Access.Set.iter (Format.fprintf fmt "@ W:%a" Access.pretty) m.cwrites ;
        Access.Set.iter (Format.fprintf fmt "@ A:%a" Access.pretty) m.cshifts ;
      end ;
    List.iter (Format.fprintf fmt "@ P:%a" pp_node) m.cparents ;
    Format.fprintf fmt "@ %a ;@]" pp_layout m.clayout ;
  end

let pp_region fmt (r : node) =
  let name = Pretty_utils.to_string pp_node r in
  pp_chunk name fmt (get r)
[@@ warning "-32"]

(* -------------------------------------------------------------------------- *)
(* --- Nodes Set                                                          --- *)
(* -------------------------------------------------------------------------- *)

module SNode = Set.Make(struct
    type t = node
    let compare r1 r2 = Int.compare (id r1) (id r2)
  end)

(* -------------------------------------------------------------------------- *)
(* --- Chunk Constructors                                                 --- *)
(* -------------------------------------------------------------------------- *)

let new_chunk_in_store s ?parent ?(size=0) ?ptr ?pointed () =
  let clayout =
    match ptr with
    | None -> if size = 0 then Blob else Cell(size,None)
    | Some _ ->
      Cell(Ranges.gcd size (bitsSizeOf Cil_const.voidPtrType), ptr)
  in
  let cparents = match parent with None -> [] | Some root -> [root] in
  let cpointed = match pointed with None -> [] | Some ptr -> [ptr] in
  make_node @@ N.new_value s { empty with clayout ; cpointed ; cparents }

let new_chunk (m: map) ?parent ?(size=0) ?ptr ?pointed () =
  failwith_locked m "Region.Memory.new_chunk" ;
  new_chunk_in_store m.store ?parent ~size ?ptr ?pointed ()

let add_label (m: map) a =
  try Lmap.find a m.labels with Not_found ->
    failwith_locked m "Region.Memory.add_label" ;
    let n = new_chunk m () in
    update n (fun d -> { d with clabels = Lset.singleton a }) ;
    m.labels <- Lmap.add a n m.labels ; n

let add_cvar (m: map) v =
  try Vmap.find v m.cvars with Not_found ->
    failwith_locked m "Region.Memory.add_varinfo" ;
    let n = new_chunk m () in
    update n (fun d -> { d with ccvars = Vset.singleton v }) ;
    m.cvars <- Vmap.add v n m.cvars ; n

let add_logic_info (m: map) f =
  try LVImap.find f m.logics with Not_found ->
    failwith_locked m "Region.Memory.add_logic_info" ;
    let get_type t = Ldomain.of_ltype (new_chunk m) t in
    let d = Option.fold ~none:Ldomain.pure ~some:get_type f.l_type in
    m.logics <- LVImap.add f d m.logics ; d

let add_logic_var (m: map) lv =
  try LVmap.find lv m.lvars with Not_found ->
    failwith_locked m "Region.Memory.add_logic_var" ;
    assert (lv.lv_origin = None);
    let d = Ldomain.of_ltype (new_chunk m) lv.lv_type in
    m.lvars <- LVmap.add lv d m.lvars ; d

let add_result (m: map) =
  let result = match m.result with
    | None -> new_chunk m ()
    | Some r -> r
  in m.result <- Some result ; result

let domain_of_typ (m:map) (typ:typ) = Ldomain.of_typ (new_chunk m) typ

let domain_of_ltyp (m:map) ?(ctxt) (lt:logic_type) =
  let d : domain = Ldomain.of_ltype (new_chunk m) lt in
  Option.fold ~none:d ~some:(fun (c:context) -> Ldomain.subst c d) ctxt

(* -------------------------------------------------------------------------- *)
(* --- Iterator                                                           --- *)
(* -------------------------------------------------------------------------- *)

let rec walk h m (f: node -> unit) n =
  let n = N.normalize @@ get_node n in
  let id = N.id n in
  try Hashtbl.find h id with Not_found ->
    Hashtbl.add h id () ;
    f @@ make_node n ;
    let r = N.get n in
    match r.clayout with
    | Blob -> ()
    | Cell(_,p) -> Option.iter (walk h m f) p
    | Compound(_,_,rg) -> Ranges.iter (walk h m f) rg

let iter (m:map) (f: node -> unit) =
  let h = Hashtbl.create 0 in
  Vmap.iter   (fun _x n ->           walk h m f n) m.cvars ;
  LVmap.iter  (fun _ -> Ldomain.iter (walk h m f)) m.lvars ;
  LVImap.iter (fun _ -> Ldomain.iter (walk h m f)) m.logics ;
  Option.iter (walk h m f) m.result

let size (r: node) =
  sizeof (N.get @@ get_node r).clayout

let parents (r: node) =
  nodes (N.get @@ get_node r).cparents

let cvars (r: node) =
  Vset.elements (N.get @@ get_node r).ccvars

let labels (r: node) =
  Lset.elements (N.get @@ get_node r).clabels

(* -------------------------------------------------------------------------- *)
(* --- Merge                                                              --- *)
(* -------------------------------------------------------------------------- *)

type queue = (node * node) Queue.t
type cell = { mutable size : int ; mutable ptr : node option }
let new_cell ?(size=0) ?ptr () = { size ; ptr }
let cell_layout { size ; ptr } =
  if size = 0 && ptr = None then Blob else Cell(size,ptr)

let merge_push (q: queue) (a: node) (b: node) : unit =
  if not @@ equal a b then Queue.push (a,b) q

let merge_node (q: queue) (a: node) (b: node) : node =
  merge_push q a b ;
  normalize @@ min a b

let merge_opt (q: queue) (pa : node option) (pb : node option) : node option =
  match pa, pb with
  | None, p | p, None -> p
  | Some pa, Some pb -> Some (merge_node q pa pb)

let merge_cell (q:queue) cell root r =
  let node = get r in
  let s = sizeof node.clayout in
  let p = cpointed node.clayout in
  begin
    merge_push q root r ;
    cell.size <- Ranges.gcd cell.size s ;
    cell.ptr <- merge_opt q cell.ptr p ;
  end

let merge_range s (q: queue) (ra : rg) (rb : rg) : node =
  let na = ra.data in
  let nb = rb.data in
  let r = merge_node q na nb in
  let ma = ra.offset + ra.length in
  let mb = rb.offset + rb.length in
  let dp = ra.offset - rb.offset in
  let dq = ma - mb in
  if dp = 0 && dq = 0 then r else
    let sa = sizeof (get na).clayout in
    let sb = sizeof (get nb).clayout in
    let size = Ranges.(sa %. sb %. dp %. dq) in
    if (sa = 0 || sa = size) && (sb = 0 || sb = size)
    then r (* merged size is compatible with dp and dq *)
    else merge_node q r (new_chunk_in_store s ~size ())

let merge_ranges s (q: queue) (root: node)
    (sa : int) (fa : Fields.domain) (wa : node Ranges.t)
    (sb : int) (fb : Fields.domain) (wb : node Ranges.t)
  : layout =
  if sa = sb then
    match Ranges.merge (merge_range s q) wa wb with
    | R [{ offset = 0 ; length ; data }] when length = sa ->
      merge_push q root data ; (get data).clayout
    | ranges ->
      let fields = Fields.union fa fb in
      Compound(sa, fields, ranges)
  else
    let size = Ranges.gcd sa sb in
    let cell = new_cell ~size () in
    Ranges.iter (merge_cell q cell root) wa ;
    Ranges.iter (merge_cell q cell root) wb ;
    cell_layout cell

let merge_layout s (q:queue) (root:node) (a:layout) (b:layout) : layout =
  match a, b with
  | Blob, c | c, Blob -> c

  | Cell(sa,pa) , Cell(sb,pb) -> Cell(Ranges.gcd sa sb, merge_opt q pa pb)

  | Compound(sa,fa,wa), Compound(sb,fb,wb) ->
    merge_ranges s q root sa fa wa sb fb wb

  | Compound(sr,_,wr), Cell(sx,ptr)
  | Cell(sx,ptr), Compound(sr,_,wr) ->
    let size = Ranges.gcd sx sr in
    let cell = new_cell ~size ?ptr () in
    Ranges.iter (merge_cell q cell root) wr ;
    cell_layout cell

let merge_chunk s (q:queue) (root:node)
    (a : chunk) (b : chunk) : chunk =
  {
    cparents = nodes @@ N.bag a.cparents b.cparents ;
    cpointed = nodes @@ N.bag a.cpointed b.cpointed ;
    clabels = Lset.union a.clabels b.clabels ;
    ccvars = Vset.union a.ccvars b.ccvars ;
    creads = Access.Set.union a.creads b.creads ;
    cwrites = Access.Set.union a.cwrites b.cwrites ;
    cshifts = Access.Set.union a.cshifts b.cshifts ;
    clayout = merge_layout s q root a.clayout b.clayout ;
    cid = max (-1) @@ min a.cid b.cid ;
  }

let do_merge (q: queue) (a: node) (b: node): unit =
  begin
    let ca = get a in
    let cb = get b in
    let rt = N.union (get_node a) (get_node b) in
    let nrt =  make_node rt in
    let ck = merge_chunk (N.get_map @@ get_node a) q nrt ca cb in
    let cparents = List.filter (fun r -> not @@ equal r nrt) ck.cparents in
    let ck = { ck with cparents } in
    N.set rt ck ;
  end

let merge_all = function
  | [] -> ()
  | r::rs ->
    let q = Queue.create () in
    List.iter (fun r' -> ignore @@ merge_node q r r') rs ;
    while not @@ Queue.is_empty q do
      let a,b = Queue.pop q in
      do_merge q a b ;
    done

let merge (m: map) (a: node) (b: node) : unit =
  failwith_locked m "Region.Memory.merge" ;
  merge_all [a;b]

let merge_domain (m:map) = Ldomain.merge (fun a b -> merge m a b ; min a b)

(* -------------------------------------------------------------------------- *)
(* --- Offset                                                             --- *)
(* -------------------------------------------------------------------------- *)

let add_field (m:map) (r:node) (fd:fieldinfo) : node =
  let ci = fd.fcomp in
  if not ci.cstruct then r else
    let size = bitsSizeOf (Cil_const.mk_tcomp ci) in
    let offset, length = Cil.fieldBitsOffset fd in
    if offset = 0 && size = length then r else
      let data = new_chunk m ~parent:r () in
      let ranges = Ranges.singleton { offset ; length ; data } in
      let fields = Fields.singleton fd in
      let clayout = Compound(size,fields,ranges) in
      let nc = make_node @@ N.new_value m.store { empty with clayout } in
      merge m r nc ; data

let add_index (m:map) (r:node) (ty:typ) : node =
  let size = bitsSizeOf ty in
  let re = new_chunk m ~size () in
  merge m r re ; re

let add_points_to (m: map) (a: node) (b : node) =
  begin
    failwith_locked m "Region.Memory.points_to" ;
    merge m a @@ new_chunk m ~ptr:b () ;
    merge m b @@ new_chunk m ~pointed:a () ;
  end

let add_value (m:map) (rv:node) (ty:typ) : node option =
  if Ast_types.is_ptr ty then
    begin
      failwith_locked m "Region.Memory.add_value" ;
      let rp = new_chunk m ~pointed:rv () in
      merge m rv @@ new_chunk m ~ptr:rp () ;
      Some rp
    end
  else
    None

(* -------------------------------------------------------------------------- *)
(* --- Access                                                             --- *)
(* -------------------------------------------------------------------------- *)

let sized (m:map) (a:node) (ty: typ) =
  if Ast_types.is_scalar ty then
    let sr = sizeof (get a).clayout in
    let size = Ranges.gcd sr (bitsSizeOf ty) in
    if sr <> size then ignore (merge m a (new_chunk m ~size ()))

let add_read (m: map) (a: node) acs =
  failwith_locked m "Region.Memory.read" ;
  let r = get a in
  N.set (get_node a) { r with creads = Access.Set.add acs r.creads } ;
  sized m a @@ Access.typeof acs

let add_write (m: map) (a: node) acs =
  failwith_locked m "Region.Memory.write" ;
  let r = get a in
  N.set (get_node a) { r with cwrites = Access.Set.add acs r.cwrites } ;
  sized m a @@ Access.typeof acs

let add_shift (m: map) (a: node) acs =
  failwith_locked m "Region.Memory.shift" ;
  let r = get a in
  N.set (get_node a) { r with cshifts = Access.Set.add acs r.cshifts } ;
  sized m a @@ Access.typeof acs

(* -------------------------------------------------------------------------- *)
(* --- Lookup                                                            ---- *)
(* -------------------------------------------------------------------------- *)

let points_to (r : node) : node option =
  let rg = get r in
  match rg.clayout with
  | Blob | Compound _ | Cell(_,None) -> None
  | Cell(_,Some r) -> Some (normalize r)

let pointed_by (r : node) =
  let rg = get r in rg.cpointed

let cvar (m: map) (v: varinfo) : node =
  normalize @@ Vmap.find v m.cvars

let logic_info (m: map) (l: logic_info) =
  LVImap.find l m.logics

let lvar (m: map) (v: logic_var) =
  LVmap.find v m.lvars

let rec move (m: map) (r: node) (p: int) (s: int) =
  let c = get r in
  match c.clayout with
  | Blob | Cell _ -> r
  | Compound(s0,_,rgs) ->
    if s0 <= s then r else
      let rg = Ranges.find p rgs in
      move m rg.data (p - rg.offset) s

let field (m: map) (r: node) (fd: fieldinfo) : node =
  if fd.fcomp.cstruct then
    let s = bitsSizeOf fd.ftype in
    let (p,_) = Cil.fieldBitsOffset fd in
    move m r p s
  else r

let footprint (r: node) : node list =
  try
    let visited = ref SNode.empty (* set of visited & normalized nodes *) in
    let leaves = ref [] (* returned leaves *) in
    let rec visit (r: node) : unit =
      let n = normalize r in (* normalized node *)
      if SNode.mem n !visited then () else
        let () = visited := SNode.add n !visited in
        let rg = (* raises Not_found *) get n in
        match rg.clayout with
        | Compound (_, _, range) -> Ranges.iter visit range
        | Blob | Cell (_,_) -> leaves := n :: !leaves
    in visit r ; !leaves
  with Not_found -> []

let index (m : map) (r: node) (ty:typ) : node =
  move m r 0 (bitsSizeOf ty)

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
  | NoOffset -> normalize r
  | Field (fd, ofs) ->
    offset m (field m r fd) fd.ftype ofs
  | Index (_, ofs) ->
    let te = Ast_types.direct_element_type ty in
    offset m (index m r te) te ofs

and exp (m: map) (e: exp) : node option =
  match e.enode with
  | Const _
  | SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _ | AlignOfE _ -> None
  | Lval lv -> points_to @@ lval m lv
  | AddrOf lv | StartOf lv -> Some (lval m lv)
  | CastE(_, e) -> exp m e
  | BinOp((PlusPI|MinusPI),p,_,_) -> exp m p
  | UnOp (_, _, _) | BinOp (_, _, _, _) -> None

let result (m: map) = m.result

(* -------------------------------------------------------------------------- *)

let included source target : bool =
  let exception Reached in
  try
    let q = Queue.create () in (* only marked nodes *)
    let push r =
      let r = normalize r in
      if equal target r then raise Reached else Queue.push r q
    in
    push source ;
    let visited = Hashtbl.create 0 in
    while true do
      let node = Queue.pop q in
      if equal target node then raise Exit else
        let id = id node in
        if not @@ Hashtbl.mem visited id then
          begin
            Hashtbl.add visited id () ;
            List.iter push (parents node) ;
          end
    done ;
    assert false
  with
  | Queue.Empty -> false
  | Reached -> true

let separated r1 r2 =
  not (included r1 r2) && not (included r2 r1)

let single_path r0 r s =
  match (get r0).clayout with
  | Blob -> true
  | Cell(s0,_) -> s = s0
  | Compound(_,_,R rgs) ->
    List.for_all
      (fun (rg : node Ranges.range) ->
         not (equal r rg.data) || rg.length = s
      ) rgs

let rec singleton r =
  let node = get r in
  (* normalized parents *)
  match nodes node.cparents with
  | [] -> Vset.cardinal node.ccvars = 1
  | [r0] ->
    Vset.is_empty node.ccvars &&
    single_path r0 r (sizeof node.clayout) &&
    (* r != r0 && (* This test may be useful to prevent infinity loops. *) *)
    singleton r0
  | _ -> false

(* -------------------------------------------------------------------------- *)

let reads (r:node) =
  let node = get r in
  List.map Access.typeof @@ Access.Set.elements node.creads

let writes (r:node) =
  let node = get r in
  List.map Access.typeof @@ Access.Set.elements node.cwrites

let shifts (r:node) =
  let node = get r in
  List.map Access.typeof @@ Access.Set.elements node.cshifts

let types (r:node) = ctypes @@ get r

let typed (r:node) =
  let types = ref None in
  let node = get r in
  let size = sizeof node.clayout in
  try
    let check acs =
      let t = Access.typeof acs in
      match Ast_types.unroll_skel t with
      | TVoid | TFun _ -> ()
      | _ ->
        if bitsSizeOf t > size then raise Exit ;
        match !types with
        | None -> types := Some t
        | Some t0 -> if not @@ Cil_datatype.Typ.equal t0 t then raise Exit
    in
    Access.Set.iter check node.creads ;
    Access.Set.iter check node.cwrites ;
    !types
  with Exit -> None

(* -------------------------------------------------------------------------- *)
(* --- High-Level API                                                     --- *)
(* -------------------------------------------------------------------------- *)

type root = Root of {
    label: string ; (* pretty printed root *)
    cvar : varinfo ;
    cells : int ;
  }

type range = Range of {
    label: string ; (* pretty printed fields *)
    offset: int ;
    length: int ;
    cells: int ;
    data: node ;
  }

type region = {
  node: node ;
  parents: node list ;
  cvars: root list ;
  labels: string list ;
  types: typ list ;
  typed : typ option ;
  fields: Fields.domain ;
  reads: Access.acs list ;
  writes: Access.acs list ;
  shifts: Access.acs list ;
  sizeof: int ;
  singleton : bool ;
  ranges: range list ;
  pointed: node option ;
}

(* -------------------------------------------------------------------------- *)
(* --- Pretty Printers                                                    --- *)
(* -------------------------------------------------------------------------- *)

let pp_cells fmt = function
  | 1 -> ()
  | 0 -> Format.fprintf fmt "[%t]" Unicode.pp_ellipsis
  | n -> Format.fprintf fmt "[%d]" n

type slice =
  | Padding of int
  | Slice of range

let pad p q s =
  let n = q - p in
  if n > 0 then Padding n :: s else s

let rec span k s = function
  | [] -> pad k s []
  | (Range rg as r)::rs ->
    pad k rg.offset @@ Slice r :: span (rg.offset + rg.length) s rs

let pp_slice fields fmt = function
  | Padding n ->
    Format.fprintf fmt "@ %a;" Fields.pp_bits n
  | Slice (Range r) ->
    Format.fprintf fmt "@ %t: %a%a;"
      (Fields.pslice ~fields ~offset:r.offset ~length:r.length)
      pp_node r.data
      pp_cells r.cells

let pp_range fmt (Range r) =
  Format.fprintf fmt "@ %d..%d: %a%a;"
    r.offset (r.offset + r.length) pp_node r.data pp_cells r.cells

let pp_root fmt (Root r) =
  Format.fprintf fmt "%a%a" Varinfo.pretty r.cvar pp_cells r.cells

let pp_region fmt (m: region) =
  begin
    let acs r s = if s = [] then '-' else r in
    Format.fprintf fmt "@[<hov 2>%a: %c%c%c"
      pp_node m.node
      (acs 'R' m.reads) (acs 'W' m.writes) (acs 'A' m.shifts) ;
    List.iter (Format.fprintf fmt "@ %s:") m.labels ;
    List.iter (Format.fprintf fmt "@ %a" pp_root) m.cvars ;
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

let pp_node fmt n = pp_node fmt n

(* -------------------------------------------------------------------------- *)
(* --- Consolidated Accessors                                             --- *)
(* -------------------------------------------------------------------------- *)

let make_root s (v : Cil_types.varinfo) : root =
  let cells = if s = 0 then 0 else bitsSizeOf v.vtype / s in
  let label = Format.asprintf "%a%a" Varinfo.pretty v pp_cells cells in
  Root { cvar = v ; cells ; label }

let make_range fields Ranges.{ length ; offset ; data } : range =
  let s = sizeof (get data).clayout in
  let cells = if s = 0 then 0 else length / s in
  let label = Format.asprintf "%t%a"
      (Fields.pslice ~fields ~offset ~length) pp_cells cells
  in Range { offset ; length ; cells ; label ; data = normalize data }

let ranges (r:node) =
  let node = get r in
  let fields = cfields node.clayout in
  List.map (make_range fields) (cranges node.clayout)

let make_region (n: node) (r: chunk) : region =
  let types = ctypes r in
  let typed = typed n in
  let sizeof = sizeof r.clayout in
  let fields = cfields r.clayout in
  let singleton = singleton n in
  {
    node = n ;
    parents = nodes r.cparents ;
    cvars = List.map (make_root sizeof) @@ Vset.elements r.ccvars ;
    labels = Lset.elements r.clabels ;
    reads = Access.Set.elements r.creads ;
    writes = Access.Set.elements r.cwrites ;
    shifts = Access.Set.elements r.cshifts ;
    ranges = List.map (make_range fields) (cranges r.clayout) ;
    pointed = Option.map (normalize) (cpointed r.clayout) ;
    types ; typed ; singleton ; sizeof ; fields ;
  }

let region n = make_region n (get n)

let regions map =
  let pool = ref [] in
  iter map (fun r -> pool := region r :: !pool) ;
  List.rev !pool

(* -------------------------------------------------------------------------- *)
(* --- Lock the map & set stable ids                                      --- *)
(* -------------------------------------------------------------------------- *)

let lock m =
  let id : int ref = ref 1 in
  let set_stable_id n =
    N.set_id (get_node n) !id ;
    id := ! id + 1 ;
  in
  iter m (set_stable_id) ;
  m.locked <- true

let unlock m = m.locked <- false

(* -------------------------------------------------------------------------- *)
