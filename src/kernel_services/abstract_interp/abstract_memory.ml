(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

(* Ocaml compiler incorrectly considers that module MemorySafe is unused and
   emits a warning *)
[@@@warning "-60"]

exception Not_implemented

open Abstract_offset

type size = Integer.t

(* Composition operator for compare function *)

let (<?>) c (cmp,x,y) =
  if c = 0 then cmp x y else c

(* Pretty printing for iterators - inspired by Pretty_utils.pp_iter *)

let pp_iter
    ?(pre=format_of_string "{@;<1 2>")
    ?(sep=format_of_string ",@;<1 2>")
    ?(suf=format_of_string "@ }")
    ?(format=format_of_string "@[<hv>%a@]")
    iter pp fmt v =
  let need_sep = ref false in
  Format.fprintf fmt pre;
  iter (fun v ->
      if !need_sep then Format.fprintf fmt sep else need_sep := true;
      Format.fprintf fmt format pp v;
    ) v;
  Format.fprintf fmt suf

let pp_iter2 ?pre ?sep ?suf ?(format=format_of_string "@[<hv>%a%a@]")
    iter2 pp_key pp_val fmt v =
  let iter f = iter2 (fun k v -> f (k,v)) in
  let pp fmt (k,v) = Format.fprintf fmt format pp_key k pp_val v in
  pp_iter ?pre ?sep ?suf ~format:"%a" iter pp fmt v

(* Types compatibility *)

let typ_size t =
  Integer.of_int (Cil.bitsSizeOf t)

let are_typ_compatible t1 t2 =
  Integer.equal (typ_size t1) (typ_size t2)


(* ------------------------------------------------------------------------ *)
(* --- Imprecise bits abstraction                                       --- *)
(* ------------------------------------------------------------------------ *)

type bit =
  | Uninitialized
  | Zero
  | Any of Base.SetLattice.t

module Bit =
struct
  module Bases = Base.SetLattice

  type t = bit

  let uninitialized = Uninitialized
  let zero = Zero
  let numerical = Any Bases.empty
  let top = Any Bases.top

  let is_any = function Any _ -> true | _ -> false

  let hash = function
    | Uninitialized -> 7
    | Zero -> 3
    | Any set -> Bases.hash set

  let equal d1 d2 =
    match d1,d2 with
    | Uninitialized, Uninitialized -> true
    | Zero, Zero -> true
    | Any set1, Any set2 -> Bases.equal set1 set2
    | _, _ -> false

  let compare d1 d2 =
    match d1,d2 with
    | Uninitialized, Uninitialized -> 0
    | Zero, Zero -> 0
    | Any set1, Any set2 -> Bases.compare set1 set2
    | Uninitialized, _ -> 1
    | _, Uninitialized -> -1
    | Zero, _ -> 1
    | _, Zero -> -1

  let is_included d1 d2 =
    match d1, d2 with
    | Uninitialized, _ -> true
    | _, Uninitialized -> false
    | Zero, _ -> true
    | _, Zero -> false
    | Any set1, Any set2 -> Bases.is_included set1 set2

  let join d1 d2 =
    match d1, d2 with
    | Uninitialized, d | d, Uninitialized -> d
    | Zero, d | d, Zero -> d
    | Any set1, Any set2 -> Any (Bases.join set1 set2)
end


(* ------------------------------------------------------------------------ *)
(* --- Inputs parameters for Memory abstraction                         --- *)
(* ------------------------------------------------------------------------ *)

module type Value =
sig
  type t

  val name : string

  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int

  val pretty : Format.formatter -> t -> unit
  val of_bit : bit -> t
  val to_bit : t -> bit
  val is_included : t -> t -> bool
  val join : t -> t -> t
end

module type Config =
sig
  val deps : State.t list
end


(* ------------------------------------------------------------------------ *)
(* --- Proto memory abstraction                                         --- *)
(* ------------------------------------------------------------------------ *)

type side = Left | Right
type oracle = Cil_types.exp -> Ival.t
type bioracle = side -> oracle
type strength = Strong | Weak | Reinforce (* update strength *)

module type ProtoMemory =
sig
  type t
  type value

  val pretty : Format.formatter -> t -> unit
  val pretty_root : Format.formatter -> t -> unit
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int

  val of_raw : bit -> t
  val raw : t -> bit
  val of_value : Cil_types.typ -> value -> t
  val to_value : Cil_types.typ -> t -> value
  val weak_erase : bit -> t -> t
  val is_included : t -> t -> bool
  val unify : oracle:bioracle ->
    (size:size -> value -> value -> value) -> t -> t -> t
  val join : oracle:bioracle -> t -> t -> t
  val smash : oracle:oracle -> t -> t -> t
  val read : oracle:oracle -> (Cil_types.typ -> t -> 'a) -> ('a -> 'a -> 'a) ->
    Abstract_offset.typed_offset -> t -> 'a
  val write : oracle:oracle -> (weak:bool -> Cil_types.typ -> t -> t) ->
    weak:bool -> Abstract_offset.typed_offset -> t -> t
  val incr_bound : oracle:oracle -> Cil_types.varinfo -> Integer.t option ->
    t -> t
end


(* ------------------------------------------------------------------------ *)
(* --- C struct abstraction                                             --- *)
(* ------------------------------------------------------------------------ *)

module type Structures =
sig
  type t
  type submemory
  val pretty : Format.formatter -> t -> unit
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val raw : t -> Bit.t
  val of_raw : Bit.t -> t
  val weak_erase : Bit.t -> t -> t
  val is_included : t -> t -> bool
  val unify : (submemory -> submemory -> submemory) -> t -> t -> t
  val read : t -> Cil_types.fieldinfo -> submemory
  val write : t -> Cil_types.fieldinfo -> (submemory -> submemory) -> t
  val map : (submemory -> submemory) -> t -> t
end

module Structures (Config : Config) (M : ProtoMemory) =
struct
  module Field =
  struct
    include Cil_datatype.Fieldinfo
    let id f = f.Cil_types.forder (* At each node, all fields come from the same comp *)
  end
  module Values =
  struct
    include Datatype.Make (
      struct
        include Datatype.Serializable_undefined
        include M
        let name = "Abstract_Memort.Structures.Values"
        let reprs = [ of_raw Zero ]
      end)
    let pretty_debug = pretty
  end
  module Initial_Values = struct let v = [[]] end
  module Deps = struct let l = Config.deps end

  module FieldMap =
    Hptmap.Make (Field) (Values) (Hptmap.Comp_unused) (Initial_Values) (Deps)

  type t = {
    padding: Bit.t;
    fields: FieldMap.t;
  }

  type submemory = M.t

  let pretty fmt m =
    pp_iter2 ~format:"@[<hv>.%a%a@]" FieldMap.iter Field.pretty M.pretty fmt m.fields

  let hash m =
    Hashtbl.hash (m.padding, FieldMap.hash m.fields)

  let equal m1 m2 =
    FieldMap.equal m1.fields m2.fields &&
    Bit.equal m1.padding m2.padding

  let compare m1 m2 =
    FieldMap.compare m1.fields m2.fields <?>
    (Bit.compare, m1.padding, m2.padding)

  let raw m =
    FieldMap.fold (fun _ x acc -> Bit.join acc (M.raw x)) m.fields m.padding

  let of_raw m =
    { padding = m ; fields = FieldMap.empty }

  let weak_erase b m =
    {
      padding = Bit.join b m.padding ;
      fields = FieldMap.map (M.weak_erase b) m.fields ;
    }

  let is_included m1 m2 =
    Bit.is_included m1.padding m2.padding &&
    let decide_fast s t = if s == t then FieldMap.PTrue else PUnknown in
    let decide_fst _fi m1 = M.is_included m1 (M.of_raw m2.padding) in
    let decide_snd _fi m2 = M.is_included (M.of_raw m1.padding) m2 in
    let decide_both _fi m1 m2 = M.is_included m1 m2 in
    FieldMap.binary_predicate Hptmap_sig.NoCache UniversalPredicate
      ~decide_fast ~decide_fst ~decide_snd ~decide_both
      m1.fields m2.fields

  let unify f m1 m2 =
    let decide b =
      FieldMap.Traversing (fun _fi m -> Some (f (M.of_raw b) m))
    in
    let decide_both _fi = fun m1 m2 -> Some (f m1 m2)
    and decide_left = decide m2.padding
    and decide_right = decide m1.padding
    in
    let fields = FieldMap.merge
        ~cache:Hptmap_sig.NoCache ~symmetric:false ~idempotent:true
        ~decide_both ~decide_left ~decide_right
        m1.fields m2.fields
    in { padding = Bit.join m1.padding m2.padding ; fields }

  let read m fi =
    try
      FieldMap.find fi m.fields
    with Not_found -> (* field undefined *)
      M.of_raw m.padding

  let write m fi f =
    let write' opt =
      Some (f (Option.value ~default:(M.of_raw m.padding) opt))
    in
    { m with fields = FieldMap.replace write' fi m.fields }

  let map f m =
    { m with fields = FieldMap.map f m.fields }
end


(* ------------------------------------------------------------------------ *)
(* --- Arrays abstraction                                               --- *)
(* ------------------------------------------------------------------------ *)

type comparison = Equal | Lower | Greater | Uncomparable

module Bound =
struct
  module Var = Cil_datatype.Varinfo
  module Exp = Cil_datatype.ExpStructEq

  type t =
    | Const of Integer.t
    | Exp of Cil_types.exp * Integer.t (* x + c *)
    | Ptroffset of Cil_types.exp * Cil_types.offset * Integer.t (* (x - &b.offset) + c *)

  let pretty fmt : t -> unit = function
    | Const i -> Integer.pretty fmt i
    | Exp (e,i) when Integer.is_zero i -> Exp.pretty fmt e
    | Exp (e,i) ->
      Format.fprintf fmt "%a + %a" Exp.pretty e Integer.pretty i
    | _ -> raise Not_implemented

  let hash : t -> int = function
    | Const i -> Hashtbl.hash (1, Integer.hash i)
    | Exp (e, i) -> Hashtbl.hash (2, Exp.hash e, Integer.hash i)
    | Ptroffset _ -> raise Not_implemented

  let compare (b1 : t) (b2 : t) : int =
    match b1, b2 with
    | Const i1, Const i2 -> Integer.compare i1 i2
    | Exp (e1, i1), Exp (e2, i2) ->
      Exp.compare e1 e2 <?> (Integer.compare, i1, i2)
    | Ptroffset _, Ptroffset _ -> raise Not_implemented
    | Const _, _ -> 1
    | _, Const _-> -1
    | Exp _, _ -> 1
    | _, Exp _ -> -1

  let equal (b1 : t) (b2 : t) : bool =
    match b1, b2 with
    | Const i1, Const i2 -> Integer.equal i1 i2
    | Exp (e1, i1), Exp (e2, i2) ->
      Exp.equal e1 e2 && Integer.equal i1 i2
    | Ptroffset _, Ptroffset _ -> raise Not_implemented
    | _, _ -> false

  let of_integer (i : Integer.t) : t =
    Const i

  let succ = function
    | Const i -> Const (Integer.succ i)
    | Exp (e, i) -> Exp (e, Integer.succ i)
    | Ptroffset _ -> raise Not_implemented

  let pred = function
    | Const i -> Const (Integer.pred i)
    | Exp (e, i) -> Exp (e, Integer.pred i)
    | Ptroffset _ -> raise Not_implemented

  exception UnsupportedBoundExpression
  exception NonLinear

  (* Find a coefficient before vi in exp *)
  let rec linearity vi exp =
    match exp.Cil_types.enode with
    | Const _
    | SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _ | AlignOfE _
    | AddrOf _ | StartOf _ -> Integer.zero
    | Lval (Var vi', NoOffset) ->
      if Var.equal  vi' vi
      then Integer.one
      else Integer.zero
    | Lval _ -> raise UnsupportedBoundExpression
    | UnOp (Neg, e, _typ) ->
      Integer.neg (linearity vi e)
    | UnOp (_, e, _typ) | CastE (_typ, e) ->
      if Integer.is_zero (linearity vi e)
      then Integer.zero
      else raise NonLinear
    | BinOp (op, e1, e2, _typ) ->
      let l1 = linearity vi e1 and l2 = linearity vi e2 in
      match op with
      | PlusA|PlusPI -> Integer.add l1 l2
      | MinusA|MinusPI -> Integer.sub l1 l2
      | _ ->
        if Integer.(is_zero l1 && is_zero l2)
        then Integer.zero
        else raise NonLinear

  let check_support exp =
    (* Check that the linearity of any variable is not hidden into a mem access *)
    ignore (linearity Var.dummy exp)

  let of_exp exp =
    check_support exp;
    (* Normalizes x + c, c + x and x - c *)
    match Cil.constFoldToInt exp with
    | Some i -> Const i
    | None ->
      match exp.Cil_types.enode with
      | BinOp ((PlusA|PlusPI), e1, e2, _typ) ->
        begin match Cil.constFoldToInt e1, Cil.constFoldToInt e2 with
          | None, Some i -> Exp (e1, i)
          | Some i, None -> Exp (e2, i)
          | _ -> Exp (exp, Integer.zero)
        end
      | BinOp ((MinusA|MinusPI), e1, e2, _typ) ->
        begin match Cil.constFoldToInt e2 with
          | Some i -> Exp (e1, Integer.neg i)
          | None -> Exp (exp, Integer.zero)
        end
      | _ -> Exp (exp, Integer.zero)

  let _of_ptr ~base_offset e =
    (* TODO: verify type compatibility between e and base_offset *)
    match of_exp e with
    | Exp (e, c) -> Ptroffset (e, base_offset, c)
    | Const _ -> assert false (* should not happen ? even with absolute adresses ? *)
    | Ptroffset _ -> assert false (* Not produced by of_exp *)

  let incr vi i b =
    try
      match b with
      | Const _ -> Some b
      | Exp (e, j) ->
        let l = linearity vi e in
        if Integer.is_zero l
        then Some b
        else Option.map (fun i -> Exp (e, Integer.(sub j (mul l i)))) i
      | Ptroffset (e, base, j) ->
        let l = linearity vi e in
        if Integer.is_zero l
        then Some b
        else Option.map (fun i -> Ptroffset (e, base, Integer.(sub j (mul l i)))) i
    with NonLinear -> None

  (* Stupid oracle built from an Ival oracle *)
  let to_ival ~oracle = function
    | Const i -> Ival.inject_singleton i
    | Exp (e, i) -> Ival.add_singleton_int i (oracle e)
    | Ptroffset _ -> raise Not_implemented

  let cmp ~oracle b1 b2 =
    if b1 == b2
    then Equal
    else
      match b1, b2 with
      | Const i1, Const i2 ->
        let r = Integer.sub i1 i2 in
        if Integer.is_zero r
        then Equal
        else if Integer.(lt r zero) then Lower else Greater
      | _, _ ->
        let r = Ival.sub_int (to_ival ~oracle b1) (to_ival ~oracle b2) in
        match Ival.min_and_max r with
        | Some min, Some max when Integer.is_zero min && Integer.is_zero max ->
          Equal
        | Some l, _ when Integer.(gt l zero) -> Greater
        | _, Some u when Integer.(lt u zero) -> Lower
        | _ -> Uncomparable

  let lower_bound ~oracle b1 b2 =
    let i1 = to_ival ~oracle:(oracle Left) b1
    and i2 = to_ival ~oracle:(oracle Right) b2 in
    let l1 = Option.get (Ival.min_int i1) (* TODO: handle Nones *)
    and l2 = Option.get (Ival.min_int i2) in
    Const (Integer.min l1 l2)

  let upper_bound ~oracle b1 b2 =
    let i1 = to_ival ~oracle:(oracle Left) b1
    and i2 = to_ival ~oracle:(oracle Right) b2 in
    let u1 = Option.get (Ival.max_int i1) (* TODO: handle Nones *)
    and u2 = Option.get (Ival.max_int i2) in
    Const (Integer.max u1 u2)

  let upper_const ~oracle b =
    Const (Option.get (Ival.min_int (to_ival ~oracle b))) (* TODO: handle exception *)

  let lower_const ~oracle b =
    Const (Option.get (Ival.min_int (to_ival ~oracle b))) (* TODO: handle exception *)
end

module type Segmentation =
sig
  type bound = Bound.t
  type submemory
  type t
  val pretty : Format.formatter -> t -> unit
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val raw : t -> Bit.t
  val weak_erase : Bit.t -> t -> t
  val is_included : t -> t -> bool
  val unify : oracle:bioracle -> (submemory -> submemory -> submemory) ->
    t -> t -> t
  val single : bit -> bound -> bound -> submemory -> t
  val read :
    oracle:(Cil_types.exp -> Ival.t) ->
    (submemory -> 'a) -> ('a -> 'a -> 'a) -> t -> bound -> 'a
  val write : oracle:oracle -> (submemory -> submemory) ->
    t -> bound -> bound -> t
  val incr_bound :
    oracle:oracle -> Bound.Var.t -> Integer.t option -> t -> t
  val map : (submemory -> submemory) -> t -> t
end

module Segmentation (Config : Config) (M : ProtoMemory) =
struct
  type bound = Bound.t
  type submemory = M.t

  type t = {
    start: bound;
    segments: (M.t * bound) list; (* should not be empty *)
    padding: bit (* padding at the left and right of the segmentation *)
  }

  let _pretty_debug fmt (l,s) : unit =
    Format.fprintf fmt " {%a} " Bound.pretty l;
    let pp fmt (v,u) =
      Format.fprintf fmt "%a {%a} " M.pretty v Bound.pretty u
    in
    List.iter (pp fmt) s

  let pretty_segments fmt (l,s) : unit =
    let pp fmt (l,v,u) =
      let u = Bound.pred u in (* Upper bound is not included *)
      if Bound.(equal l u) then
        Format.fprintf fmt "[%a]%a" Bound.pretty l M.pretty v
      else
        Format.fprintf fmt "[%a..%a]%a" Bound.pretty l Bound.pretty u M.pretty v
    in
    match s with
    | [] -> Format.fprintf fmt "[]" (* should not happen *)
    | [(v,u)] -> pp fmt (l,v,u)
    | _ :: _ ->
      let iter l f segments =
        (* fold the previous upper bound = the current lower bound *)
        ignore (List.fold_left (fun l (v,u) -> f (l,v,u) ; u) l segments)
      in
      pp_iter (iter l) pp fmt s

  let pretty fmt (m : t) : unit =
    pretty_segments fmt (m.start,m.segments)

  let hash (m : t) : int =
    Hashtbl.hash (
      Bound.hash m.start,
      List.map (fun (v,u) -> Hashtbl.hash (M.hash v, Bound.hash u)) m.segments,
      Bit.hash m.padding)

  let compare (m1 : t) (m2 : t) : int =
    let compare_segments (v1,u1) (v2,u2) =
      M.compare v1 v2 <?> (Bound.compare, u1, u2)
    in
    Bound.compare m1.start m2.start <?>
    (Transitioning.List.compare compare_segments, m1.segments, m2.segments) <?>
    (Bit.compare, m1.padding, m2.padding)

  let equal (m1 : t) (m2 : t) : bool =
    let equal_segments (v1,u1) (v2,u2) =
      M.equal v1 v2 && Bound.equal u1 u2
    in
    Bound.equal m1.start m2.start &&
    Transitioning.List.equal equal_segments m1.segments m2.segments &&
    Bit.equal m1.padding m2.padding

  let raw (m : t) : bit =
    (* Perhaps some segments are empty, but we are not going to test it for now *)
    List.fold_left
      (fun acc (v,_u) -> Bit.join acc (M.raw v))
      m.padding m.segments

  let weak_erase (b : bit) (m : t) : t =
    {
      m with
      segments = List.map (fun (v,u) -> M.weak_erase b v, u) m.segments ;
      padding = Bit.join b m.padding ;
    }

  let is_included (m1 : t) (m2 : t) : bool =
    let included_segments (v1,u1) (v2,u2) =
      M.is_included v1 v2 &&
      Bound.equal u1 u2
    in
    Bound.equal m1.start m2.start &&
    Bit.is_included m1.padding m2.padding &&
    try
      List.for_all2 included_segments m1.segments m2.segments
    with Invalid_argument _ -> false (* Segmentations have different sizes *)

  let is_empty_segment ~oracle l u =
    match Bound.cmp ~oracle l u with
    | Equal | Greater -> true
    | Lower | Uncomparable -> false

  let check_segments s = (* TODO: remove *)
    match s with
    | [] -> assert false
    | s -> s

  (* Merge the two first slices of a segmentation *)
  exception NothingToMerge
  let merge_first ~oracle l = function
    | [] | [_] -> raise NothingToMerge
    | (v1,m) :: (v2,u) :: tail ->
      let v1' = if is_empty_segment ~oracle l m then `Bottom else `Value v1
      and v2' = if is_empty_segment ~oracle m u then `Bottom else `Value v2
      in
      match Bottom.join (M.smash ~oracle) v1' v2' with
      | `Bottom -> tail
      | `Value v -> (v,u) :: tail

  let unify ~oracle f (m1 (*Left*): t) (m2 (*Right*) : t) : t =
    (* Shortcuts *)
    let compare side = Bound.cmp ~oracle:(oracle side) in
    let equals side b1 b2 =
      compare side b1 b2 = Equal
    in
    let join side =
      let oracle = fun _ -> oracle side in
      Bottom.join (M.join ~oracle)
    in

    let {start=l1 ; segments=s1 ; padding=p1 } = m1
    and {start=l2 ; segments=s2 ; padding=p2 } = m2 in
    (* Unify the segmentation start *)
    let l = Bound.lower_bound ~oracle l1 l2 in
    let s1 = if equals Left l l1 then s1 else (M.of_raw p1, l1) :: s1
    and s2 = if equals Right l l2 then s2 else (M.of_raw p2, l2) :: s2
    in
    (* Unify the segmentation end *)
    let merge_first side = merge_first ~oracle:(oracle side) in
    let rec smash_end side l = function
      | [] -> `Bottom, l
      | [(v,u)] -> `Value v, u
      | t -> smash_end side l (merge_first side l t)
    in
    let unify_end l s1 s2 =
      let v1, u1 = smash_end Left l s1
      and v2, u2 = smash_end Right l s2 in
      let u = Bound.upper_bound ~oracle u1 u2 in
      let w1 =
        if equals Left u u1 then v1 else join Left (`Value (M.of_raw p1)) v1
      and w2 =
        if equals Right u u2 then v2 else join Right (`Value (M.of_raw p2)) v2
      in
      match Bottom.join f w1 w2 with
      | `Bottom -> [] (* should not happen, but [] is still correct *)
      | `Value w -> [(w,u)]
    in
    (* +----+-------+-----
       | v1 | v1'   |
       +----+-------+-----
       l    u1
       +------+-------+---
       | v2   | v2'   |
       +------+-------+---
       l      u2 *)
    let rec aux l s1 s2 acc =
      (* Look for emerging slices *)
      let left_slice_emerges = match s1 with
        | (v1,u1) :: t1 when equals Right l u1 -> Some (v1,u1,t1)
        | _ -> None
      and right_slice_emerges = match s2 with
        | (v2,u2) :: t2 when equals Left l u2 -> Some (v2,u2,t2)
        | _ -> None
      in
      match left_slice_emerges, right_slice_emerges with
      | Some (v1,u1,t1), None -> (* left slice emerges *)
        aux u1 t1 s2 ((v1,u1) :: acc)
      | None, Some (v2,u2,t2) -> (* right slice emerges *)
        aux u2 s1 t2 ((v2,u2) :: acc)
      | Some _, Some _ (* both emerges, can't choose *)
      | None, None -> (* none emerges *)
        match s1, s2 with (* Are we done yet ? *)
        | [], [] -> acc
        | _ :: _, [] | [], _ :: _-> unify_end l s1 s2 @ acc
        | (v1,u1) :: t1, (v2,u2) :: t2 ->
          try
            match compare Left u1 u2, compare Right u1 u2 with (* Compare bounds *)
            | _, Equal ->
              (* u1 and u2 can be indeferently used right side
                 -> use u1 as next bound
                 Note: Asymetric choice, u2 may also be a good choice *)
              aux u1 t1 t2 ((f v1 v2, u1) :: acc)
            | Equal, _ ->
              (* u1 and u2 can be indeferently used left side
                 -> use u2 as next bound *)
              aux u2 t1 t2 ((f v1 v2, u2) :: acc)
            | Greater, (Greater | Uncomparable) ->
              (* u1 > u2 on the left side, we are sure u2 doesn't appear left
                 -> remove u2, merge slices *)
              aux l s1 (merge_first Right l s2) acc
            | (Lower | Uncomparable), Lower ->
              (* u1 < u2 on the right side, we are sure u1 doesn't appear right
                 -> remove u1, merge slices *)
              aux l (merge_first Left l s1) s2 acc
            | Greater, Lower (* Can't choose which bound to remove first *)
            | (Lower | Uncomparable), (Greater | Uncomparable) ->
              aux l (merge_first Left l s1) (merge_first Right l s2) acc
          with NothingToMerge -> (* There is nothing left to merge *)
            unify_end l s1 s2 @ acc
    in
    (* Iterate through segmentations *)
    {
      start = l ;
      segments = check_segments (aux l s1 s2 []) ;
      padding = Bit.join p1 p2 ;
    }

  let single padding lindex uindex value =
    {
      padding ;
      start = lindex ;
      segments = check_segments [(value,uindex)] ;
    }

  let read ~oracle map reduce m index =
    let is_below = function
      | Lower-> true
      | Equal | Greater | Uncomparable -> false
    and is_above = function
      | Greater | Equal -> true
      | Lower | Uncomparable -> false
    and fold acc x =
      Bottom.join reduce acc (`Value (map x))
    in
    let aux (prev,acc) (v,u) =
      let next = Bound.cmp ~oracle index u in
      next,
      if is_below prev || is_above next then acc else fold acc v
    in
    let first = Bound.cmp ~oracle index m.start in
    let acc = `Bottom in
    let acc = if is_above first then acc else fold acc (M.of_raw m.padding) in
    let last,acc = List.fold_left aux (first,acc) m.segments in
    let acc = if is_below last then acc else fold acc (M.of_raw m.padding) in
    match acc with
    | `Bottom -> assert false (* TODO: ensure that with typing *)
    | `Value v -> v

  (* TODO: partitioning strategies
     1. reinforcement without loss
     2. weak update without singularization
     3. update reduces the number of segments to 3 *)
  let write ~oracle f m lindex uindex = (* lindex < uindex *)
    let (<=) b1 b2 = match Bound.cmp ~oracle b1 b2 with
      | Lower | Equal -> true
      | Greater | Uncomparable -> false
    and (>=) b1 b2 = match Bound.cmp ~oracle b1 b2 with
      | Greater | Equal -> true
      | Lower | Uncomparable -> false
    in
    (* (start,head) : segmentation kept identical below the write indexes,
                      head is a list in reverse order
       (l,v,u) : the segment (l,u) beeing overwriten with previous value v

       head = (_,l) :: _
    *)
    let rec aux_before l s =
      (* Format.printf "aux before: %a@." pretty_segments (l,s); *)
      if lindex >= l
      then aux_below l [] l s
      else aux_over lindex [] lindex (M.of_raw m.padding) l s
    and aux_below start head l = fun t ->
      (* Format.printf "aux_below: %a [%a] %a@." pretty_segments (start,head) Bound.pretty l pretty_segments (l,t); *)
      match t with (* l <= lindex *)
      | [] ->
        aux_end start head l (M.of_raw m.padding) uindex []
      | (v,u) :: t ->
        if lindex >= u
        then aux_below start ((v,u) :: head) u t
        else aux_over start head l v u t
    and aux_over start head l v u s = (* l <= lindex *)
      (* Format.printf "aux_over: %a [%a,%a,%a] %a@." pretty_segments (start,head) Bound.pretty l M.pretty v Bound.pretty u pretty_segments (u,s); *)
      if uindex <= u then
        aux_end start head l v u s
      else
        match s with
        | [] ->
          aux_end start head l (M.smash ~oracle v (M.of_raw m.padding)) uindex []
        | (v',u') :: t ->
          (* TODO: do not smash if the slices are covered by the write *)
          aux_over start head l (M.smash ~oracle v v') u' t
    and aux_end start head l v u tail = (* l <= lindex < uindex <= u*)
      (* Format.printf "aux_end: %a [%a,%a,%a] %a@." pretty_segments (start,head) Bound.pretty l M.pretty v Bound.pretty u pretty_segments (u,tail); *)
      let tail' =
        (if is_empty_segment ~oracle l lindex then [] else [(v,lindex)]) @
        [(f v,uindex)] @
        (if is_empty_segment ~oracle uindex u then [] else [(v,u)]) @
        tail
      in
      {
        m with
        segments = check_segments (List.rev_append head tail');
        start ;
      }
    in
    aux_before m.start m.segments

  let incr_bound ~oracle vi x m =
    let rec aux acc = function
      | [] -> acc
      | (v,u) :: t ->
        match Bound.incr vi x u with
        | Some u -> aux ((v,u) :: acc) t
        | None ->
          match t with
          | [] ->
            let u = Bound.upper_const ~oracle u
            and v = M.smash ~oracle (M.of_raw m.padding) v in
            (v,u) :: acc
          | (v',u') :: t -> aux ((M.smash ~oracle v v',u') :: acc) t
    in
    let start, segments =
      match Bound.incr vi x m.start with
      | Some start -> start, m.segments
      | None ->
        match m.segments with
        | [] -> assert false
        | (v,u) :: t ->
          let l = Bound.lower_const ~oracle m.start
          and v = M.smash ~oracle (M.of_raw m.padding) v in
          l, (v,u) :: t
    in
    {  m with start ; segments = check_segments (List.rev (aux [] segments)) }

  let map f m =
    { m with segments = check_segments (List.map (fun (v,u) -> f v, u) m.segments) }
end


(* ------------------------------------------------------------------------ *)
(* --- Typed memory abstraction                                         --- *)
(* ------------------------------------------------------------------------ *)

module TypedMemory (Config : Config) (V : Value) =
struct
  (* Recursively instanciate the typed memory *)
  module rec ProtoMemory : ProtoMemory with type value = V.t =
  struct
    type value = V.t

    type t =
      | Raw of bit
      | Scalar of memory_scalar
      | Struct of memory_struct
      | Union of memory_union
      | Array of memory_array
    and memory_scalar = {
      scalar_value: V.t;
      scalar_type: Cil_types.typ;
    }
    and memory_struct = {
      struct_value: S.t;
      struct_type: Cil_types.compinfo;
    }
    (* unions are handled separately from struct to avoid confusion and error *)
    and memory_union = {
      union_value: t;
      union_field: Cil_types.fieldinfo;
      union_padding: bit;
    }
    and memory_array = {
      array_value: A.t;
      array_cell_type: Cil_types.typ;
    }

    let are_scalar_compatible s1 s2 =
      are_typ_compatible s1.scalar_type s2.scalar_type

    let are_aray_compatible a1 a2 =
      are_typ_compatible a1.array_cell_type a2.array_cell_type

    let are_structs_compatible s1 s2 =
      s1.struct_type.ckey = s2.struct_type.ckey

    let are_union_compatible u1 u2 =
      Cil_datatype.Fieldinfo.equal u1.union_field u2.union_field

    let rec pp ~root fmt =
      let prefix fmt =
        if not root then Format.fprintf fmt " = "
      in
      let pretty_bit fmt = function
        | Uninitialized -> Format.fprintf fmt "UNINITIALIZED"
        | Zero -> Format.fprintf fmt "0"
        | Any (Set set) when Base.SetLattice.O.is_empty set ->
          Format.fprintf fmt "[--..--]"
        | Any _ -> Format.fprintf fmt "T"
      in
      function
      | Raw b ->
        Format.fprintf fmt "%t%a" prefix pretty_bit b
      | Scalar { scalar_value } ->
        Format.fprintf fmt "%t%a" prefix V.pretty scalar_value
      | Struct s ->
        Format.fprintf fmt "%t%a" prefix S.pretty s.struct_value
      | Union u ->
        Format.fprintf fmt ".%s%a"
          u.union_field.Cil_types.fname
          (pp ~root:false) u.union_value
      | Array a ->
        Format.fprintf fmt "%a" A.pretty a.array_value

    let pretty fmt m = pp ~root:false fmt m
    let pretty_root fmt m =
      Format.fprintf fmt "@[<hv>%a@]" (pp ~root:true) m

    let rec hash m = match m with
      | Raw b -> Hashtbl.hash (
          1,
          Bit.hash b)
      | Scalar s -> Hashtbl.hash (
          2,
          V.hash s.scalar_value,
          Cil_datatype.Typ.hash s.scalar_type)
      | Struct s -> Hashtbl.hash (
          3,
          S.hash s.struct_value,
          Cil_datatype.Compinfo.hash s.struct_type)
      | Union u -> Hashtbl.hash (
          4,
          hash u.union_value,
          Cil_datatype.Fieldinfo.hash u.union_field,
          Bit.hash u.union_padding)
      | Array a -> Hashtbl.hash (
          5,
          A.hash a.array_value,
          Cil_datatype.Typ.hash a.array_cell_type)

    let rec equal m1 m2 =
      match m1, m2 with
      | Raw b1, Raw b2 -> Bit.equal b1 b2
      | Scalar s1, Scalar s2 ->
        V.equal s1.scalar_value s2.scalar_value &&
        Cil_datatype.Typ.equal s1.scalar_type s2.scalar_type
      | Struct s1, Struct s2 ->
        S.equal s1.struct_value s2.struct_value &&
        Cil_datatype.Compinfo.equal s1.struct_type s2.struct_type
      | Union u1, Union u2 ->
        equal u1.union_value u2.union_value &&
        Bit.equal u1.union_padding u2.union_padding &&
        Cil_datatype.Fieldinfo.equal u1.union_field u2.union_field
      | Array a1, Array a2 ->
        A.equal a1.array_value a2.array_value &&
        Cil_datatype.Typ.equal a1.array_cell_type a2.array_cell_type
      | (Raw _ | Scalar _ | Struct _ | Union _ | Array _), _ -> false

    let rec compare m1 m2 =
      let (<?>) c (cmp,x,y) =
        if c = 0 then cmp x y else c
      in
      match m1, m2 with
      | Raw b1, Raw b2 -> Bit.compare b1 b2
      | Scalar s1, Scalar s2 ->
        V.compare s1.scalar_value s2.scalar_value <?>
        (Cil_datatype.Typ.compare, s1.scalar_type, s2.scalar_type)
      | Struct s1, Struct s2 ->
        S.compare s1.struct_value s2.struct_value <?>
        (Cil_datatype.Compinfo.compare, s1.struct_type, s2.struct_type)
      | Union u1, Union u2 ->
        compare u1.union_value u2.union_value <?>
        (Bit.compare, u1.union_padding, u2.union_padding) <?>
        (Cil_datatype.Fieldinfo.compare, u1.union_field, u2.union_field)
      | Array a1, Array a2 ->
        A.compare a1.array_value a2.array_value <?>
        (Cil_datatype.Typ.compare, a1.array_cell_type, a2.array_cell_type)
      | Raw _, _ -> 1
      | _, Raw _ -> -1
      | Scalar _, _ -> 1
      | _, Scalar _ -> -1
      | Struct _, _ -> 1
      | _, Struct _ -> -1
      | Union _, _ -> 1
      | _, Union _ -> -1

    let of_raw b = Raw b

    let rec raw m = match m with
      | Raw b -> b
      | Scalar s -> V.to_bit s.scalar_value
      | Struct s -> S.raw s.struct_value
      | Union u -> raw u.union_value
      | Array a -> A.raw a.array_value

    let of_value scalar_type scalar_value =
      Scalar { scalar_type ; scalar_value }

    let to_value typ = function
      | Scalar s when are_typ_compatible s.scalar_type typ -> s.scalar_value
      | m -> V.of_bit (raw m)

    let rec weak_erase b = function
      | Raw b' ->
        Raw (Bit.join b' b)
      | Scalar s when Bit.is_any b ->
        Raw (Bit.join (V.to_bit s.scalar_value) b)
      | Scalar s ->
        Scalar { s with scalar_value = V.(join (of_bit b) s.scalar_value) }
      | Array a ->
        Array { a with array_value = A.weak_erase b a.array_value }
      | Struct s ->
        Struct { s with struct_value = S.weak_erase b s.struct_value }
      | Union u -> Union {
          u with
          union_padding = Bit.join u.union_padding b;
          union_value = weak_erase b u.union_value;
        }

    let rec is_included m1 m2 = match m1, m2 with
      | _, Raw r -> Bit.is_included (raw m1) r
      | Scalar s1, Scalar s2 ->
        are_scalar_compatible s1 s2 &&
        V.is_included s1.scalar_value s2.scalar_value
      | Array a1, Array a2 ->
        are_aray_compatible a1 a2 &&
        A.is_included a1.array_value a2.array_value
      | Struct s1, Struct s2 ->
        are_structs_compatible s1 s2 &&
        S.is_included s1.struct_value s2.struct_value
      | Union u1, Union u2 ->
        are_union_compatible u1 u2 &&
        Bit.is_included u1.union_padding u2.union_padding &&
        is_included u1.union_value u2.union_value
      | Raw _, (Scalar _ | Array _ | Struct _ | Union _)
      | Scalar _, (Array _ | Struct _ | Union _)
      | Array _, (Scalar _ | Struct _ | Union _)
      | Struct _, (Scalar _ | Array _ | Union _)
      | Union _, (Scalar _ | Array _ | Struct _) -> false

    let unify ~oracle f =
      let rec aux m1 m2 =
        match m1, m2 with
        | Raw b1, Raw b2 -> Raw (Bit.join b1 b2)
        | m, Raw b | Raw b, m -> weak_erase b m
        | Scalar s1, Scalar s2
          when are_typ_compatible s1.scalar_type s2.scalar_type ->
          let size = typ_size s1.scalar_type in
          let scalar_value = f ~size s1.scalar_value s2.scalar_value in
          Scalar { s1 with scalar_value }
        | Array a1, Array a2 when are_aray_compatible a1 a2 ->
          let array_value = A.unify ~oracle aux a1.array_value a2.array_value in
          Array { a1 with array_value }
        | Struct s1, Struct s2 when are_structs_compatible s1 s2 ->
          let struct_value = S.unify aux s1.struct_value s2.struct_value in
          Struct { s1 with struct_value }
        | Union u1, Union u2 when are_union_compatible u1 u2 ->
          Union {
            u1 with
            union_value = aux u1.union_value u2.union_value;
            union_padding = Bit.join u1.union_padding u2.union_padding;
          }
        | _,_ ->
          Raw (Bit.join (raw m1) (raw m2))
      in
      aux

    let join ~oracle = unify ~oracle (fun ~size:_ -> V.join)

    let smash ~oracle = join ~oracle:(fun _ -> oracle)

    let read ~oracle (map : Cil_types.typ -> t -> 'a) (reduce : 'a -> 'a -> 'a) =
      let rec aux offset m =
        match offset, m with
        | NoOffset t, m ->
          map t m
        | Field (fi, offset'), Struct s
          when s.struct_type.ckey = fi.fcomp.ckey ->
          aux offset' (S.read s.struct_value fi)
        | Field (fi, offset'), Union u
          when Cil_datatype.Fieldinfo.equal u.union_field fi ->
          aux offset' u.union_value
        | Index (exp, _index, elem_type, offset'), Array a
          when are_typ_compatible a.array_cell_type elem_type ->
          A.read ~oracle (aux offset') reduce a.array_value (Bound.of_exp (Option.get exp)) (* TODO: handle None *)
        | _, m -> (* structure mismatch *)
          let r = Raw (raw m) in
          match offset with
          | NoOffset t -> map t r
          | Field (_, offset') | Index (_, _, _, offset') -> aux offset' r
      in
      aux

    let write ~oracle (f : weak:bool -> Cil_types.typ -> t -> t) =
      let rec aux ~weak offset m =
        match offset with
        | NoOffset t ->
          f ~weak t m
        | Field (fi, offset') ->
          if fi.fcomp.cstruct then (* Structures *)
            let old = match m with
              | Struct s when s.struct_type.ckey = fi.fcomp.ckey -> s
              | _ -> { struct_type = fi.fcomp ; struct_value = S.of_raw (raw m) }
            in
            Struct {
              old with
              struct_value = S.write old.struct_value fi (aux ~weak offset')
            }
          else (* Unions *)
            let old = match m with
              | Union u when Cil_datatype.Fieldinfo.equal u.union_field fi -> u
              | _ ->
                let b = raw m in
                { union_value = Raw b ; union_field = fi ; union_padding = b }
            in
            Union {
              old with
              union_value = aux ~weak offset' old.union_value
            }
        | Index (exp, index, elem_type, offset') ->
          let lindex, uindex, weak = match exp with
            | None ->
              let l, u = Int_val.min_and_max index in
              let l = Option.get l and u = Option.get u in (* TODO: handle exceptions *)
              Bound.of_integer l, Bound.of_integer u,
              weak || Integer.equal l u
            | Some e ->
              let b = Bound.of_exp e in
              b, b, weak
          in
          match m with
          | Array a when are_typ_compatible a.array_cell_type elem_type ->
            let array_value = A.write ~oracle (aux ~weak offset') a.array_value
                lindex (Bound.succ uindex) in
            Array { a with array_value }
          | _ ->
            let b = raw m in
            let new_value = aux ~weak offset' (Raw b) in
            let array_value = A.single b lindex (Bound.succ uindex) new_value in
            Array { array_cell_type = elem_type ; array_value }
      in aux

    let incr_bound ~oracle vi x = (* TODO: keep subtree when nothing changes *)
      let rec aux = function
        | (Raw _ | Scalar _) as m -> m
        | Struct s -> Struct { s with struct_value = S.map aux s.struct_value }
        | Union u -> Union { u with union_value = aux u.union_value }
        | Array a ->
          let array_value = A.incr_bound ~oracle vi x a.array_value in
          Array { a with array_value=A.map aux array_value }
      in aux
  end
  and S : Structures with type submemory = ProtoMemory.t =
    Structures (Config) (ProtoMemory)
  and A : Segmentation with type submemory = ProtoMemory.t =
    Segmentation (Config) (ProtoMemory)

  include ProtoMemory

  type location = Abstract_offset.typed_offset

  let pretty = pretty_root

  (* Constuctors *)

  let top = of_raw Bit.top
  let zero = of_raw Bit.zero
  let is_top m = m = top

  (* Widening *)

  let widen = unify

  (* Read/Write accesses *)

  let get ~oracle (m : t) (loc : location) : value =
    read ~oracle to_value V.join loc m

  let extract ~oracle (m : t) (loc : location) : t =
    let r = read ~oracle (fun _typ x -> x) (smash ~oracle) loc m in
    (* Format.printf "extract %a in %a : %a@." TypedOffset.pretty loc pretty m pretty r; *)
    r

  let set ~oracle ~weak m offset new_v =
    let f ~weak typ m =
      of_value typ (if weak then V.join (to_value typ m) new_v else new_v)
    in
    let r = write ~oracle ~weak f offset m in
    (* Format.printf "%a <- %a : %a@." TypedOffset.pretty offset V.pretty new_v pretty r; *)
    r

  let join ~oracle m1 m2 =
    let r = join ~oracle m1 m2 in
    (* Format.printf "%a join %a : %a@." pretty m1 pretty m2 pretty r; *)
    r

  let reinforce ~oracle f m offset =
    let f' ~weak typ m =
      if weak then m else of_value typ (f (to_value typ m))
    in
    let r = write ~oracle ~weak:false f' offset m in
    (* Format.printf "reinforce at %a : %a@." TypedOffset.pretty offset pretty r; *)
    r

  let erase ~oracle ~weak m offset b =
    let f ~weak _typ m =
      if weak then
        weak_erase b m
      else
        of_raw b
    in
    write ~oracle ~weak f offset m

  let overwrite ~oracle ~weak dst offset src =
    let f ~weak _typ m =
      if weak then
        smash ~oracle m src
      else
        src
    in
    write ~oracle ~weak f offset dst
end
