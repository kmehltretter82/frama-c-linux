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
open Bottom.Type

type size = Integer.t


let dunify = false
let dread = false
let dwrite = false
let demerging = false

let dp = ref 0
let debug b format =
  incr dp;
  if b then
    Kernel.debug ~current:true ("#%d " ^^ format) ~level:0 !dp
  else Kernel.debug format ~level:50

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

type initialization =
  | SurelyInitialized
  | MaybeUninitialized

type bit =
  | Uninitialized
  | Zero of initialization
  | Any of Base.SetLattice.t * initialization

module Initialization =
struct
  let pretty fmt = function
    | SurelyInitialized -> ()
    | MaybeUninitialized ->
      Format.fprintf fmt "or UNINITIALIZED"

  let hash = function
    | SurelyInitialized -> 3
    | MaybeUninitialized -> 7

  let equal i1 i2 =
    match i1, i2 with
    | SurelyInitialized, SurelyInitialized
    | MaybeUninitialized, MaybeUninitialized -> true
    | _, _ -> false

  let compare i1 i2 =
    match i1, i2 with
    | SurelyInitialized, SurelyInitialized
    | MaybeUninitialized, MaybeUninitialized -> 0
    | SurelyInitialized, MaybeUninitialized -> -1
    | MaybeUninitialized, SurelyInitialized -> 1

  let is_included i1 i2 =
    match i1, i2 with
    | SurelyInitialized, _
    | _, MaybeUninitialized -> true
    | MaybeUninitialized, SurelyInitialized -> false

  let join i1 i2 =
    match i1, i2 with
    | SurelyInitialized, SurelyInitialized -> SurelyInitialized
    | MaybeUninitialized, _
    | _, MaybeUninitialized -> MaybeUninitialized
end

module Bit =
struct
  module Bases = Base.SetLattice

  type t = bit

  let uninitialized = Uninitialized
  let zero = Zero SurelyInitialized
  let numerical = Any (Bases.empty, SurelyInitialized)
  let top = Any (Bases.top, MaybeUninitialized)


  let pretty fmt = function
    | Uninitialized ->
      Format.fprintf fmt "UNINITIALIZED"
    | Zero i ->
      Format.fprintf fmt "0%a" Initialization.pretty i
    | Any (Set set, i) when Base.SetLattice.O.is_empty set ->
      Format.fprintf fmt "[--..--]%a" Initialization.pretty i
    | Any _ -> Format.fprintf fmt "T"

  let is_any = function Any _ -> true | _ -> false

  let hash = function
    | Uninitialized -> 7
    | Zero i -> Hashtbl.hash (3, Initialization.hash i)
    | Any (set, i)-> Hashtbl.hash (53, Bases.hash set, Initialization.hash i)

  let equal d1 d2 =
    match d1,d2 with
    | Uninitialized, Uninitialized -> true
    | Zero i1, Zero i2 -> Initialization.equal i1 i2
    | Any (set1,i1), Any (set2,i2) ->
      Bases.equal set1 set2 && Initialization.equal i1 i2
    | _, _ -> false

  let compare d1 d2 =
    match d1,d2 with
    | Uninitialized, Uninitialized -> 0
    | Zero i1, Zero i2 -> Initialization.compare i1 i2
    | Any (set1,i1), Any (set2,i2) ->
      Bases.compare set1 set2 <?> (Initialization.compare, i1, i2)
    | Uninitialized, _ -> 1
    | _, Uninitialized -> -1
    | Zero _, _ -> 1
    | _, Zero _-> -1

  let initialization = function
    | Uninitialized -> MaybeUninitialized
    | Zero i -> i
    | Any (_,i) -> i

  let is_included d1 d2 =
    Initialization.is_included (initialization d1) (initialization d2) &&
    match d1, d2 with
    | Uninitialized, _ -> true
    | _, Uninitialized -> false
    | Zero _, _ -> true
    | _, Zero _ -> false
    | Any (set1,_), Any (set2,_) -> Bases.is_included set1 set2

  let join d1 d2 =
    match d1, d2 with
    | Uninitialized, Uninitialized -> Uninitialized
    | Zero i1, Zero i2 ->
      Zero (Initialization.join i1 i2)
    | Any (set1,i1), Any (set2,i2) ->
      Any (Bases.join set1 set2, Initialization.join i1 i2)
    | Zero _, Uninitialized
    | Uninitialized, Zero _ -> Zero MaybeUninitialized
    | Any (set,i), (Zero _ | Uninitialized as b)
    | (Zero _ | Uninitialized as b), Any (set,i) ->
      Any (set, Initialization.join i (initialization b))
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
  val to_integer : t -> Integer.t option
  val is_included : t -> t -> bool
  val join : t -> t -> t
end

module type Config =
sig
  val deps : State.t list
  val slice_limit : unit -> int
  val disjunctive_invariants : unit -> bool
end


(* ------------------------------------------------------------------------ *)
(* --- Proto memory abstraction                                         --- *)
(* ------------------------------------------------------------------------ *)

type side = Left | Right
type oracle = Cil_types.exp -> Ival.t
type bioracle = side -> oracle
type strength = Strong | Weak | Reinforce (* update strength *)

let no_oracle = fun _exp -> Ival.top

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
  val to_singleton_int : t -> Integer.t option
  val weak_erase : bit -> t -> t
  val is_included : t -> t -> bool
  val unify : oracle:bioracle ->
    (size:size -> value -> value -> value) -> t -> t -> t
  val join : oracle:bioracle -> t -> t -> t
  val smash : oracle:oracle -> t -> t -> t
  val read : oracle:oracle -> (Cil_types.typ -> t -> 'a) -> ('a -> 'a -> 'a) ->
    Abstract_offset.typed_offset -> t -> 'a
  val write : oracle:oracle ->
    (weak:bool -> Cil_types.typ -> t -> t or_bottom) ->
    weak:bool -> Abstract_offset.typed_offset -> t -> t or_bottom
  val incr_bound : oracle:oracle -> Cil_types.varinfo -> Integer.t option ->
    t -> t
  val add_segmentation_bounds : oracle:oracle -> typ:Cil_types.typ ->
    Cil_types.exp list -> t -> t
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
  val write : (submemory -> submemory or_bottom) -> t -> Cil_types.fieldinfo ->
    t or_bottom
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
        let name = "Abstract_Memory.Structures.Values"
        let reprs = [ of_raw Bit.zero ]
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

  let unify f m1 m2 = (* f is not symmetric *)
    let decide_both _fi = fun m1 m2 -> Some (f m1 m2)
    and decide_left = FieldMap.Traversing (fun _fi m1 ->
        Some (f m1 (M.of_raw m2.padding)))
    and decide_right = FieldMap.Traversing (fun _fi m2 ->
        Some (f (M.of_raw m1.padding) m2))
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

  let write f m fi =
    try
      let write' opt =
        let x = Option.value ~default:(M.of_raw m.padding) opt in
        match f x with
        | `Value v -> Some v
        | `Bottom -> raise Exit
      in
      `Value { m with fields = FieldMap.replace write' fi m.fields }
    with Exit ->
      `Bottom

  let map f m =
    { m with fields = FieldMap.map f m.fields }
end


(* ------------------------------------------------------------------------ *)
(* --- Disjunctions of structures                                       --- *)
(* ------------------------------------------------------------------------ *)

(* This abstraction focus on catching structures invariants of the form

   x.f = c₁ ⇒ ϕ₁(x)  ⋁  x.f = c₂ ⇒ ϕ₂(x)  ⋁  ...

   where f is a field, c₁, c₂, ... are constants and ϕ₁, ϕ₂, ... properties about
   the structure x.

   f is called a key. During the analysis, we track fields which are assigned
   constant values, and the set of such fields is called keys. As the anlysis
   progresses, the set of key is reduced each time we discover one of the field
   is actually not a key because it is assigned with non-singleton values. *)

module type Disjunction =
sig
  type t
  type submemory
  type structure
  val pretty : Format.formatter -> t -> unit
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val raw : t -> Bit.t
  val of_raw : Cil_types.compinfo -> Bit.t -> t
  val of_struct : Cil_types.compinfo -> structure -> t
  val to_struct : oracle:oracle -> t -> structure
  val weak_erase : Cil_types.compinfo -> Bit.t -> t -> t
  val is_included : t -> t -> bool
  val unify : oracle:bioracle -> (submemory -> submemory -> submemory) ->
    t -> t -> t
  val read : (submemory -> 'a) -> ('a -> 'a -> 'a)  ->
    t -> Cil_types.fieldinfo -> 'a
  val write : oracle:oracle -> (submemory -> submemory or_bottom) ->
    t -> Cil_types.fieldinfo -> t or_bottom
  val map : (submemory -> submemory) -> t -> t
end

module Disjunction (Config : Config) (M : ProtoMemory)
    (S : Structures with type submemory = M.t) =
struct
  module Valuation =
  struct
    module FMap = Cil_datatype.Fieldinfo.Map
    module FSet = Cil_datatype.Fieldinfo.Set

    include FMap
    include FMap.Make (Datatype.Integer)
    let keys map = fold (fun k _ set -> FSet.add k set) map FSet.empty
  end

  module Map = (* 'a Map.t : (fi -> int) -> 'a *)
  struct
    module Info = struct let module_name = "Abstract_memory.Disjunction.Map" end
    include Datatype.Map (Map.Make (Valuation)) (Valuation) (Info)

    (* Defined only for Ocaml >= 4.11 *)
    let filter_map f m =
      fold (fun k x m -> match f k x with None -> m | Some y -> add k y m) m empty
  end

  module S = (* Structures in the disjunction *)
  struct
    include Datatype.Serializable_undefined
    include S
    let name = "Abstract_Memory.Disjunction.S"
    let reprs = [ of_raw Bit.zero ]
    let eval_key key m = M.to_singleton_int (read m key)
    let suitable_key key m = Option.is_some (eval_key key m)
    let keys_candidates ci m =
      let fields = Option.value ~default:[] ci.Cil_types.cfields in
      List.filter (fun fi -> suitable_key fi m) fields |>
      Valuation.FSet.of_list
    let evaluate keys m : Valuation.t =
      let update_key fi map =
        eval_key fi m |> (* should be Some *)
        Option.fold ~none:map ~some:(fun v -> Valuation.add fi v map)
      in
      Valuation.FSet.fold update_key keys Valuation.empty
  end

  include Map.Make (Datatype.Make (S))

  type submemory = M.t
  type structure = S.t

  let keys (m : t) = Valuation.keys (fst (Map.choose m))

  let pick (m : t) =
    match Map.choose_opt m with
    | None -> Kernel.fatal "The disjunction should never be empty"
    | Some (k,s) -> k,s,Map.remove k m

  let pretty fmt (m : t) =
    match Map.bindings m with
    | [] -> assert false
    | [(_,s)] -> S.pretty fmt s
    | bindings ->
      let l = List.map snd bindings in
      pp_iter ~format:"@[<hv>%a@]" ~sep:" or @;<1 2>" List.iter S.pretty fmt l

  let hash (m : t) =
    Hashtbl.hash (Map.fold (fun _ s acc -> s :: acc) m [])

  let reevaluate ~oracle keys (m : t) : t =
    let update _k s acc =
      let merge prev =
        Extlib.merge_opt (fun () -> S.unify (M.smash ~oracle)) () (Some s) prev
      in
      Map.update (S.evaluate keys s) merge acc
    in
    Map.fold update m Map.empty

  let smash ?(oracle=no_oracle) (m : t) =
    let _k,s,m = pick m in
    Map.fold (fun _k -> S.unify (M.smash ~oracle)) m s

  let of_struct (ci : Cil_types.compinfo) (s : S.t) =
    let keys = S.keys_candidates ci s in
    Map.singleton (S.evaluate keys s) s

  let to_struct ~oracle (m : t) =
    smash ~oracle m

  let raw (m : t) : bit =
    let f _ x acc =
      Bottom.join Bit.join acc (`Value (S.raw x))
    in
    Bottom.non_bottom (Map.fold f m `Bottom) (* The map should not be empty *)

  let of_raw (ci : Cil_types.compinfo) (b : bit) : t =
    let s = S.of_raw b in
    of_struct ci s

  let weak_erase (ci : Cil_types.compinfo) (b : bit) (m : t) : t =
    (* if b is Zero, more could be done as all scalar fields might be a key *)
    (* weak_erase is probably linear for the join operator, so we weak_erase
       befoire joining as this is faster. *)
    let m = Map.map (fun m -> S.weak_erase b m) m in
    let s = smash m in
    of_struct ci s

  let is_included (m1 : t) (m2 : t) : bool  =
    (* Imprecise inclusion: we only consider inclusion of disjunction where
       the set of field keys is the same *)
    let aux k s1 =
      match Map.find_opt k m2 with
      | None -> false
      | Some s2 -> S.is_included s1 s2
    in
    Map.for_all aux m1

  let unify ~oracle f (m1 : t) (m2 : t) =
    let keys = Valuation.FSet.inter (keys m1) (keys m2) in
    let m1 = reevaluate ~oracle:(oracle Left) keys m1
    and m2 = reevaluate ~oracle:(oracle Right) keys m2 in
    Map.union (fun _k m1 m2 -> Some (S.unify f m1 m2)) m1 m2

  let read map reduce (m : t) (fi : Cil_types.fieldinfo) =
    let aux _k s acc =
      map (S.read s fi) |>
      Option.fold ~none:Fun.id ~some:reduce acc |>
      Option.some
    in
    Option.get (Map.fold aux m None) (* If the map is not empty, result is Some *)

  let write ~oracle f (m : t) (fi : Cil_types.fieldinfo) =
    let m = Map.filter_map (fun _k s -> Bottom.to_option (S.write f s fi)) m in
    if Map.is_empty m then
      `Bottom
    else
      let is_key = Map.for_all (fun _k s -> S.suitable_key fi s) m in
      let old_keys = keys m in
      if is_key || Valuation.FSet.mem fi old_keys then
        let new_keys =
          if is_key
          then Valuation.FSet.add fi old_keys
          else Valuation.FSet.remove fi old_keys
        in
        `Value (reevaluate ~oracle new_keys m)
      else
        `Value (m)

  let map f m =
    Map.map (S.map f) m
end


(* ------------------------------------------------------------------------ *)
(* --- Comparison operators                                             --- *)
(* ------------------------------------------------------------------------ *)


type comparison =
  | Equal
  | Lower
  | Greater
  | LowerOrEqual
  | GreaterOrEqual
  | Uncomparable

module type Operators =
sig
  [@@@warning "-32"] (* unused operators... for now*)

  type t
  val (<) : t -> t -> bool
  val (>) : t -> t -> bool
  val (<=) : t -> t -> bool
  val (>=) : t -> t -> bool
  val (===) : t -> t -> bool
end

let operators :
  type a . (a -> a -> comparison) -> (module Operators with type t = a) =
  fun f ->
  (module struct
    type t = a

    let (<) b1 b2 = match f b1 b2 with
      | Lower -> true
      | LowerOrEqual | Equal | Greater | GreaterOrEqual | Uncomparable -> false

    let (<=) b1 b2 = match f b1 b2 with
      | Lower | Equal | LowerOrEqual -> true
      | Greater | GreaterOrEqual | Uncomparable -> false

    let (>) b1 b2 = match f b1 b2 with
      | Greater -> true
      | Equal | LowerOrEqual | Lower | GreaterOrEqual | Uncomparable -> false

    let (>=) b1 b2 = match f b1 b2 with
      | Greater | GreaterOrEqual | Equal -> true
      | Lower | LowerOrEqual | Uncomparable -> false

    let (===) b1 b2 = match f b1 b2 with
      | Equal -> true
      | GreaterOrEqual | Greater | Lower | LowerOrEqual | Uncomparable -> false
  end)


(* ------------------------------------------------------------------------ *)
(* --- Arrays abstraction                                               --- *)
(* ------------------------------------------------------------------------ *)

module Bound =
struct
  module Var = Cil_datatype.Varinfo
  module Exp =
  struct
    include Cil_datatype.ExpStructEq
    let equal e1 e2 =
      if e1 == e2 then true else equal e1 e2
  end

  type t =
    | Const of Integer.t
    | Exp of Cil_types.exp * Integer.t (* x + c *)
    | Ptroffset of Cil_types.exp * Cil_types.offset * Integer.t (* (x - &b.offset) + c *)

  let pretty fmt : t -> unit = function
    | Const i -> Integer.pretty fmt i
    | Exp (e,i) when Integer.is_zero i -> Exp.pretty fmt e
    | Exp (e,i) when Integer.(lt i zero) ->
      Format.fprintf fmt "%a - %a" Exp.pretty e Integer.pretty (Integer.neg i)
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

  (* Stupid oracle built from an Ival oracle *)
  let to_ival ~oracle = function
    | Const i -> Ival.inject_singleton i
    | Exp (e, i) -> Ival.add_singleton_int i (oracle e)
    | Ptroffset _ -> raise Not_implemented

  let to_const ~oracle = function
    | Const i -> Some i
    | Exp (e, i) ->
      begin try
          Some (Integer.add (Ival.project_int (oracle e)) i)
        with Ival.Not_Singleton_Int ->
          None
      end
    | Ptroffset _ -> raise Not_implemented

  let succ = function
    | Const i -> Const (Integer.succ i)
    | Exp (e, i) -> Exp (e, Integer.succ i)
    | Ptroffset _ -> raise Not_implemented

  let pred = function
    | Const i -> Const (Integer.pred i)
    | Exp (e, i) -> Exp (e, Integer.pred i)
    | Ptroffset _ -> raise Not_implemented

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

  let incr_or_constantify ~oracle vi i b =
    match incr vi i b with
    | Some v -> Some v
    | None -> Option.map (fun c -> Const c) (to_const ~oracle b)

  let cmp_int i1 i2 =
    let r = Integer.sub i1 i2 in
    if Integer.is_zero r
    then Equal
    else if Integer.(lt r zero) then Lower else Greater

  let cmp ~oracle b1 b2 =
    if b1 == b2
    then Equal
    else
      match b1, b2 with
      | Const i1, Const i2 -> cmp_int i1 i2
      | Exp (e1, i1), Exp (e2, i2) when Exp.equal e1 e2 -> cmp_int i1 i2
      | Ptroffset _, _ | _, Ptroffset _ -> raise Not_implemented
      | _, _ ->
        let r = Ival.sub_int (to_ival ~oracle b1) (to_ival ~oracle b2) in
        match Ival.min_and_max r with
        | Some min, Some max when Integer.is_zero min && Integer.is_zero max ->
          Equal
        | Some l, _ when Integer.(ge l zero) ->
          if Integer.(gt l zero) then Greater else GreaterOrEqual
        | _, Some u when Integer.(le u zero) ->
          if Integer.(lt u zero) then Lower else LowerOrEqual
        | _ -> Uncomparable

  let eq ?(oracle=no_oracle) b1 b2 =
    cmp ~oracle b1 b2 = Equal

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

  exception NoBound

  let lower_const ~oracle b =
    match Ival.min_int (to_ival ~oracle b) with
    | Some l -> Const l
    | None -> (* TODO: handle exception *)
      Kernel.feedback ~current:true "cannot retrieve lower bound for %a in %a"
        pretty b Ival.pretty (to_ival ~oracle b);
      raise NoBound

  let upper_const ~oracle b =
    match Ival.max_int (to_ival ~oracle b) with
    | Some u -> Const u
    | None -> (* TODO: handle exception *)
      Kernel.feedback ~current:true "cannot retrieve upper bound for %a in %a"
        pretty b Ival.pretty (to_ival ~oracle b);
      raise NoBound

  let _operators oracle = operators (cmp ~oracle)
end

module AgingBound =
struct
  type age = Integer.t
  type t = Bound.t * age

  let pretty fmt (b,_) = Bound.pretty fmt b
  let hash (b,_a) = Bound.hash b
  let compare (b1,_a1) (b2,_a2) =
    Bound.compare b1 b2
  let equal (b1,_a1) (b2,_a2) =
    Bound.equal b1 b2
  let _of_integer i a = Bound.of_integer i, a
  let _of_exp e a = Bound.of_exp e, a
  let _succ (b,a) = (Bound.succ b, a)
  let pred (b,a) = (Bound.pred b, a)
  let _incr vi i (b,a) = Bound.incr vi i b |> Option.map (fun b -> b,a)
  let incr_or_constantify ~oracle vi i (b,a) =
    Bound.incr_or_constantify ~oracle vi i b |> Option.map (fun b -> b,a)
  let _to_ival ~oracle (b,_a) = Bound.to_ival ~oracle b
  let cmp ~oracle (b1,_a1) (b2,_a2) = Bound.cmp ~oracle b1 b2
  let eq ?oracle (b1,_a1) (b2,_a2) = Bound.eq ?oracle b1 b2
  let lower_bound ~oracle (b1,a1) (b2,a2) =
    Bound.lower_bound ~oracle b1 b2, Integer.min a1 a2
  let upper_bound ~oracle (b1,a1) (b2,a2) =
    Bound.upper_bound ~oracle b1 b2, Integer.min a1 a2
  let lower_const ~oracle (b,_a) =
    Bound.lower_const ~oracle b
  let upper_const ~oracle (b,_a) =
    Bound.upper_const ~oracle b

  let birth b = b, Integer.zero
  let aging (b,a) = b, Integer.succ a
  let age (_,a) = a
  let unify_age ~other:(_,a') (b,a) = (b, Integer.min a' a)
  let operators oracle : (module Operators with type t = t) =
    operators (cmp ~oracle)
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
  val hull : oracle:oracle -> t -> bound * bound
  val raw : t -> Bit.t
  val weak_erase : Bit.t -> t -> t
  val is_included : t -> t -> bool
  val unify : oracle:bioracle -> (submemory -> submemory -> submemory) ->
    t -> t -> t
  val single : bit -> bound -> bound -> submemory -> t
  val read : oracle:oracle ->
    (submemory -> 'a) -> ('a -> 'a -> 'a) -> t -> bound -> bound -> 'a
  val write : oracle:oracle -> (submemory -> submemory or_bottom) ->
    t -> bound -> bound -> t or_bottom
  val incr_bound :
    oracle:oracle -> Bound.Var.t -> Integer.t option -> t -> t
  val map : (submemory -> submemory) -> t -> t
  val add_segmentation_bounds : oracle:oracle -> bound list -> t -> t
end

module Segmentation (Config : Config) (M : ProtoMemory) =
struct
  module B = AgingBound

  type bound = Bound.t
  type submemory = M.t

  type t = {
    start: B.t;
    segments: (M.t * B.t) list; (* should not be empty *)
    padding: bit; (* padding at the left and right of the segmentation *)
  }

  let _pretty_debug fmt (l,s) : unit =
    Format.fprintf fmt " {%a} " B.pretty l;
    let pp fmt (v,u) =
      Format.fprintf fmt "%a {%a} " M.pretty v B.pretty u
    in
    List.iter (pp fmt) s

  let pretty_segments fmt ((l : B.t), (s : (M.t * B.t) list)) : unit =
    let pp fmt (l,v,u) =
      let u = B.pred u in (* Upper bound is not included *)
      (* Less strict than B.equal even with no oracles *)
      if B.eq l u then
        Format.fprintf fmt "[%a]%a" B.pretty l M.pretty v
      else
        Format.fprintf fmt "[%a .. %a]%a" B.pretty l B.pretty u M.pretty v
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
      B.hash m.start,
      List.map (fun (v,u) -> Hashtbl.hash (M.hash v, B.hash u)) m.segments,
      Bit.hash m.padding)

  let compare (m1 : t) (m2 : t) : int =
    let compare_segments (v1,u1) (v2,u2) =
      M.compare v1 v2 <?> (B.compare, u1, u2)
    in
    B.compare m1.start m2.start <?>
    (Transitioning.List.compare compare_segments, m1.segments, m2.segments) <?>
    (Bit.compare, m1.padding, m2.padding)

  let equal (m1 : t) (m2 : t) : bool =
    let equal_segments (v1,u1) (v2,u2) =
      M.equal v1 v2 && B.equal u1 u2
    in
    B.equal m1.start m2.start &&
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
      M.is_included v1 v2 && B.eq u1 u2
    in
    B.eq m1.start m2.start &&
    Bit.is_included m1.padding m2.padding &&
    try
      List.for_all2 included_segments m1.segments m2.segments
    with Invalid_argument _ -> false (* Segmentations have different sizes *)

  let hull ~oracle (m : t) : bound * bound =
    let rec last = function
      | [] -> assert false
      | [(_v,u)] -> u
      | _ :: t -> last t
    in
    B.lower_const ~oracle m.start,
    B.upper_const ~oracle (B.pred (last m.segments))

  let is_empty_segment ~oracle l u =
    let open (val (B.operators oracle)) in
    l >= u

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

  (* Unify two arrays m1 and m2 *)
  let unify ~oracle f (m1 (*Left*): t) (m2 (*Right*) : t) : t =
    (* Shortcuts *)
    let compare side = B.cmp ~oracle:(oracle side) in
    let equals side b1 b2 =
      let r = compare side b1 b2 = Equal in
      (* Format.printf "%a (%a) = %a (%a) ? %B@."
         B.pretty b1
         Ival.pretty (B._to_ival ~oracle:(oracle side) b1)
         B.pretty b2
         Ival.pretty (B._to_ival ~oracle:(oracle side) b2)
         r; *)
      r
    in
    let smash side = Bottom.join (M.smash ~oracle:(oracle side)) in
    let {start=l1 ; segments=s1 ; padding=p1 } = m1
    and {start=l2 ; segments=s2 ; padding=p2 } = m2 in
    (* Unify the segmentation start *)
    let l = B.lower_bound ~oracle l1 l2 in
    debug dunify "%a LUB %a = %a" B.pretty l1 B.pretty l2 B.pretty l;
    let ll = l in
    let s1 = if equals Left l l1 then s1 else (M.of_raw p1, l1) :: s1
    and s2 = if equals Right l l2 then s2 else (M.of_raw p2, l2) :: s2
    in
    debug dunify "Unification start@.%a U@.%a" pretty_segments (l,s1) pretty_segments (l,s2);
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
      let u = B.upper_bound ~oracle u1 u2 in
      let w1 =
        if equals Left u u1 then v1 else smash Left (`Value (M.of_raw p1)) v1
      and w2 =
        if equals Right u u2 then v2 else smash Right (`Value (M.of_raw p2)) v2
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
      debug dunify "Unification progress@.%a U@.%a result:@.%a" pretty_segments (l,s1) pretty_segments (l,s2) pretty_segments (ll, List.rev acc);
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
        if equals Left l u1 then (* actually empty both sides*)
          aux l t1 s2 acc
        else
          aux u1 t1 s2 ((v1,B.unify_age ~other:l u1) :: acc)
      | None, Some (v2,u2,t2) -> (* right slice emerges *)
        if equals Right l u2 then (* actually empty both sides *)
          aux l s1 t2 acc
        else
          aux u2 s1 t2 ((v2,B.unify_age ~other:l u2) :: acc)
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
              aux u1 t1 t2 ((f v1 v2, B.unify_age ~other:u2 u1) :: acc)
            | Equal, _ ->
              (* u1 and u2 can be indeferently used left side
                 -> use u2 as next bound *)
              aux u2 t1 t2 ((f v1 v2, B.unify_age ~other:u1 u2) :: acc)
            | (Greater | GreaterOrEqual),
              (Greater | GreaterOrEqual | Uncomparable) ->
              (* u1 > u2 on the left side, we are sure u2 doesn't appear left
                 -> remove u2, merge slices *)
              aux l s1 (merge_first Right l s2) acc
            | (Lower | LowerOrEqual | Uncomparable),
              (Lower | LowerOrEqual) ->
              (* u1 < u2 on the right side, we are sure u1 doesn't appear right
                 -> remove u1, merge slices *)
              aux l (merge_first Left l s1) s2 acc
            | (Greater | GreaterOrEqual), (Lower | LowerOrEqual) (* Can't choose which bound to remove first *)
            | (Lower | LowerOrEqual | Uncomparable),
              (Greater | GreaterOrEqual | Uncomparable) ->
              aux l (merge_first Left l s1) (merge_first Right l s2) acc
          with NothingToMerge -> (* There is nothing left to merge *)
            unify_end l s1 s2 @ acc
    in
    let segments = List. rev (aux l s1 s2 []) in
    debug dunify "Unification result :@.%a" pretty_segments (l,segments);
    (* Iterate through segmentations *)
    {
      start = l ;
      segments = check_segments segments ;
      padding = Bit.join p1 p2 ;
    }

  let single padding lindex (* included *) uindex (* included *) value =
    {
      padding ;
      start = B.birth lindex ;
      segments = check_segments [(value,B.birth (Bound.succ uindex))] ;
    }

  let read ~oracle map reduce m lindex uindex =
    let open (val (B.operators oracle)) in
    let lindex = B.birth lindex and uindex = B.birth uindex in
    let fold acc x =
      Bottom.join reduce acc (`Value (map x))
    in
    let aux (l,acc) (v,u) =
      u, if l > uindex || u <= lindex then acc else fold acc v
    in
    let acc = `Bottom in
    let acc = if m.start <= lindex then acc else fold acc (M.of_raw m.padding) in
    let last,acc = List.fold_left aux (m.start,acc) m.segments in
    let acc = if last > uindex then acc else fold acc (M.of_raw m.padding) in
    match acc with
    | `Bottom -> assert false (* TODO: ensure that with typing *)
    | `Value v -> v

  let aging m = (* Extremities do not age *)
    let rec aux acc = function
      | [] -> acc
      | [x] -> x :: acc
      | (v,b) :: t -> aux ((v,B.aging b) :: acc) t
    in
    { m with segments = List.rev (aux [] m.segments) }

  let oldest_inner_bound m =
    match m.segments with (* ignore m.start bound *)
    | [] -> None
    | (_,b) :: t ->
      let rec aux acc = function
        | [] -> None
        | [_] -> Some acc (* ignore last bound *)
        | (_,b) :: t -> aux (max acc (B.age b)) t
      in
      aux (B.age b) t

  let remove_oldest_bounds ~oracle m =
    match oldest_inner_bound m with
    | None -> m (* no inner bounds, should not happen if segments_limit > 2 *)
    | Some oldest_age ->
      (* Remvoe all bounds of this age *)
      let rec aux acc l = function
        | ([] | [_]) as t -> List.rev (t @ acc)
        | ((v,u) :: t) as s ->
          if B.age u = oldest_age then
            aux acc l (merge_first ~oracle l s)
          else
            aux ((v,u) :: acc) u t
      in
      { m with segments = aux [] m.start m.segments }

  let limit_size ~oracle m =
    let limit = Config.slice_limit () in
    let rec aux m =
      if List.length m.segments <= limit
      then m
      else aux (remove_oldest_bounds ~oracle m)
    in
    aux m


  (* TODO: partitioning strategies
     1. reinforcement without loss
     2. weak update without singularization
     3. update reduces the number of segments to 3 *)
  let write ~oracle f m lindex (* included *) uindex (* excluded *) = (* lindex < uindex *)
    let open (val (B.operators oracle)) in
    let same_bounds = lindex == uindex in
    let lindex = B.birth lindex and uindex = B.birth uindex in
    (* (start,head) : segmentation kept identical below the write indexes,
                      head is a list in reverse order
       (l,v,u) : the segment (l,u) beeing overwriten with previous value v

       head = (_,l) :: _
    *)
    let rec aux_before l s =
      debug dwrite "aux before: %a@." pretty_segments (l,s);
      debug dwrite "%a (%a) >= %a (%a) ? %B@." B.pretty lindex Ival.pretty (B._to_ival ~oracle lindex) B.pretty l Ival.pretty (B._to_ival ~oracle l) (lindex >= l);
      if lindex >= l
      then aux_below l [] l s
      else aux_over lindex [] lindex (M.of_raw m.padding) l s
    and aux_below start head l = fun t ->
      debug dwrite "aux_below: %a <{%a}> %a@." pretty_segments (start,head) B.pretty l pretty_segments (l,t);
      match t with (* l <= lindex *)
      | [] ->
        aux_end start head l (M.of_raw m.padding) uindex []
      | (v,u) :: t ->
        debug dwrite "%a (%a) >= %a (%a) ? %B@." B.pretty lindex Ival.pretty (B._to_ival ~oracle lindex) B.pretty u Ival.pretty (B._to_ival ~oracle u) (lindex >= u);
        if lindex >= u
        then aux_below start ((v,u) :: head) u t
        else aux_over start head l v u t
    and aux_over start head l v u s = (* l <= lindex *)
      debug dwrite "aux_over: %a <{%a} %a {%a}> %a@." pretty_segments (start,head) B.pretty l M.pretty v B.pretty u pretty_segments (u,s);
      if uindex <= u then
        aux_end start head l v u s
      else
        match s with
        | [] ->
          let u = B.upper_bound ~oracle:(fun _ -> oracle) u uindex
          and v = M.smash ~oracle v (M.of_raw m.padding) in
          aux_end start head l v u []
        | (v',u') :: t ->
          (* TODO: do not smash if the slices are covered by the write *)
          aux_over start head l (M.smash ~oracle v v') u' t
    and aux_end start head l v u tail = (* l <= lindex < uindex <= u*)
      debug dwrite  "aux_end: %a <{%a} %a {%a}> %a@." pretty_segments (start,head) B.pretty l M.pretty v B.pretty u pretty_segments (u,tail);
      f v >>-: fun new_v ->
      let previous_is_empty = is_empty_segment ~oracle l lindex
      and next_is_empty = is_empty_segment ~oracle uindex u in
      let tail' =
        (if previous_is_empty then [] else [(v,lindex)]) @
        (if same_bounds then [] else [(new_v,uindex)]) @
        (if next_is_empty then [] else [(v,u)]) @
        tail
      and head',start' = match head with (* change last bound to match lindex *)
        | (v',_u) :: t when previous_is_empty -> (v',lindex) :: t, start
        | [] when previous_is_empty -> [], lindex
        | head -> head, start
      in
      {
        m with
        segments = check_segments (List.rev_append head' tail');
        start = start';
      }
    in
    aux_before m.start m.segments >>-:
    aging >>-:
    limit_size ~oracle

  let incr_bound ~oracle vi x m =
    let incr = B.incr_or_constantify ~oracle vi x in
    let rec aux acc = function
      | [] -> acc
      | (v,u) :: t ->
        match incr u with
        | Some u -> aux ((v,u) :: acc) t
        | None ->
          match t with
          | [] ->
            let u = B.upper_const ~oracle u, snd u
            and v = M.smash ~oracle (M.of_raw m.padding) v in
            (v,u) :: acc
          | (v',u') :: t -> aux acc ((M.smash ~oracle v v',u') :: t)
    in
    let start, segments =
      match incr m.start with
      | Some start -> start, m.segments
      | None ->
        match m.segments with
        | [] -> assert false
        | (v,u) :: t ->
          let l = B.lower_const ~oracle m.start, snd m.start
          and v = M.smash ~oracle (M.of_raw m.padding) v in
          l, (v,u) :: t
    in
    { m with start ; segments = check_segments (List.rev (aux [] segments)) }

  let map f m =
    { m with segments = check_segments (List.map (fun (v,u) -> f v, u) m.segments) }

  let add_segmentation_bounds ~oracle bounds m =
    let add_bound m b =
      Bottom.non_bottom (write ~oracle (fun x -> `Value x) m b b)
    in
    List.fold_left add_bound m bounds
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
      | Disjunct of memory_disjunct
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
    and memory_disjunct = {
      disj_value: D.t;
      disj_type: Cil_types.compinfo;
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

    let are_compinfo_compatible ci1 ci2 =
      ci1.Cil_types.ckey = ci2.Cil_types.ckey

    let are_structs_compatible s1 s2 =
      s1.struct_type.ckey = s2.struct_type.ckey

    let are_disjuncts_compatible d1 d2 =
      d1.disj_type.ckey = d2.disj_type.ckey

    let are_union_compatible u1 u2 =
      Cil_datatype.Fieldinfo.equal u1.union_field u2.union_field

    let rec pp ~root fmt =
      let prefix fmt =
        if not root then Format.fprintf fmt " = "
      in
      function
      | Raw b ->
        Format.fprintf fmt "%t%a" prefix Bit.pretty b
      | Scalar { scalar_value } ->
        Format.fprintf fmt "%t%a" prefix V.pretty scalar_value
      | Struct s ->
        Format.fprintf fmt "%t%a" prefix S.pretty s.struct_value
      | Disjunct d ->
        Format.fprintf fmt "%t%a" prefix D.pretty d.disj_value
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
      | Disjunct d -> Hashtbl.hash (
          4,
          D.hash d.disj_value,
          Cil_datatype.Compinfo.hash d.disj_type
        )
      | Union u -> Hashtbl.hash (
          5,
          hash u.union_value,
          Cil_datatype.Fieldinfo.hash u.union_field,
          Bit.hash u.union_padding)
      | Array a -> Hashtbl.hash (
          6,
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
      | Disjunct d1, Disjunct d2 ->
        D.equal d1.disj_value d2.disj_value &&
        Cil_datatype.Compinfo.equal d1.disj_type d2.disj_type
      | Union u1, Union u2 ->
        equal u1.union_value u2.union_value &&
        Bit.equal u1.union_padding u2.union_padding &&
        Cil_datatype.Fieldinfo.equal u1.union_field u2.union_field
      | Array a1, Array a2 ->
        A.equal a1.array_value a2.array_value &&
        Cil_datatype.Typ.equal a1.array_cell_type a2.array_cell_type
      | (Raw _ | Scalar _ | Struct _ | Disjunct _ |  Union _ | Array _), _ ->
        false

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
      | Disjunct d1, Disjunct d2 ->
        D.compare d1.disj_value d2.disj_value <?>
        (Cil_datatype.Compinfo.compare, d1.disj_type, d2.disj_type)
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
      | Disjunct _, _ -> 1
      | _, Disjunct _ -> -1
      | Union _, _ -> 1
      | _, Union _ -> -1

    let of_raw b = Raw b

    let rec raw m = match m with
      | Raw b -> b
      | Scalar s -> V.to_bit s.scalar_value
      | Struct s -> S.raw s.struct_value
      | Disjunct d -> D.raw d.disj_value
      | Union u -> raw u.union_value
      | Array a -> A.raw a.array_value

    let of_value scalar_type scalar_value =
      Scalar { scalar_type ; scalar_value }

    let to_value typ = function
      | Scalar s when are_typ_compatible s.scalar_type typ -> s.scalar_value
      | m -> V.of_bit (raw m)

    let rec to_singleton_int = function
      | Scalar s -> V.to_integer s.scalar_value
      | Raw (Zero _) -> Some Integer.zero
      | Union u -> to_singleton_int u.union_value
      | _ -> None

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
      | Disjunct d ->
        Disjunct { d with disj_value = D.weak_erase d.disj_type b d.disj_value }
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
      | Disjunct d1, Disjunct d2 ->
        are_disjuncts_compatible d1 d2 &&
        D.is_included d1.disj_value d2.disj_value
      | Union u1, Union u2 ->
        are_union_compatible u1 u2 &&
        Bit.is_included u1.union_padding u2.union_padding &&
        is_included u1.union_value u2.union_value
      | (Raw _ | Scalar _ | Array _ | Struct _ | Disjunct _ | Union _), _ ->
        false

    let to_struct ~oracle ci = function
      | Struct s when are_compinfo_compatible s.struct_type ci ->
        s.struct_value
      | Disjunct d when are_compinfo_compatible d.disj_type ci ->
        D.to_struct ~oracle d.disj_value
      | m -> S.of_raw (raw m)

    let to_disj ci = function
      | Struct s when are_compinfo_compatible s.struct_type ci ->
        D.of_struct ci s.struct_value
      | Disjunct d when are_compinfo_compatible d.disj_type ci ->
        d.disj_value
      | m -> D.of_raw ci (raw m)

    let unify ~oracle f =
      let raw_to_array ~oracle side prototype b =
        let l,u = A.hull ~oracle:(oracle side) prototype in
        A.single b l u (Raw b)
      in
      let rec aux m1 m2 =
        debug dunify "unification between@.%a and@.%a" pretty m1 pretty m2;
        match m1, m2 with
        | Raw b1, Raw b2 -> Raw (Bit.join b1 b2)
        | Scalar s1, Scalar s2
          when are_typ_compatible s1.scalar_type s2.scalar_type ->
          let size = typ_size s1.scalar_type in
          let scalar_value = f ~size s1.scalar_value s2.scalar_value in
          Scalar { s1 with scalar_value }
        | Array a1, Array a2 when are_aray_compatible a1 a2 ->
          let array_value = A.unify ~oracle aux a1.array_value a2.array_value in
          Array { a1 with array_value }
        | Array a1, Raw b2 ->
          begin try
              let array_value2 = raw_to_array ~oracle Left a1.array_value b2 in
              let array_value = A.unify ~oracle aux a1.array_value array_value2 in
              debug demerging "emerging unification between@.%a and@.%a result:@.%a"
                A.pretty a1.array_value
                A.pretty array_value2
                A.pretty array_value;
              Array { a1 with array_value }
            with Bound.NoBound ->
              weak_erase b2 m1 (* TODO: find a better way to handle this case *)
          end
        | Raw b1, Array a2 ->
          begin try
              let array_value1 = raw_to_array ~oracle Right a2.array_value b1 in
              let array_value = A.unify ~oracle aux array_value1 a2.array_value in
              debug demerging "emerging unification between@.%a and@.%a result:@.%a"
                A.pretty array_value1
                A.pretty a2.array_value
                A.pretty array_value;
              Array { a2 with array_value }
            with Bound.NoBound ->
              weak_erase b1 m2 (* TODO: find a better way to handle this case *)
          end
        | Struct s1, Struct s2 when are_structs_compatible s1 s2 ->
          let struct_value = S.unify aux s1.struct_value s2.struct_value in
          Struct { s1 with struct_value }
        | Struct s, Raw _ | Raw _, Struct s ->
          (* Previously implemented as weak_erase, it is useful to continue
             the recursive unification as there can be an emerging array segment
             in the sub structure. *)
          let v1 = to_struct ~oracle:(oracle Left) s.struct_type m1
          and v2 = to_struct ~oracle:(oracle Right) s.struct_type m2 in
          let struct_value = S.unify aux v1 v2 in
          Struct { s with struct_value }
        | Disjunct d1, Disjunct d2 when are_disjuncts_compatible d1 d2 ->
          let disj_value = D.unify ~oracle aux d1.disj_value d2.disj_value in
          Disjunct { d1 with disj_value }
        | Disjunct d, Raw _ | Raw _, Disjunct d ->
          let v1 = to_disj d.disj_type m1
          and v2 = to_disj d.disj_type m2 in
          let disj_value = D.unify ~oracle aux v1 v2 in
          Disjunct { d with disj_value }
        | Union u1, Union u2 when are_union_compatible u1 u2 ->
          Union {
            u1 with
            union_value = aux u1.union_value u2.union_value;
            union_padding = Bit.join u1.union_padding u2.union_padding;
          }
        | m, Raw b | Raw b, m -> weak_erase b m
        | _,_ -> Raw (Bit.join (raw m1) (raw m2))
      in
      aux

    let join ~oracle = unify ~oracle (fun ~size:_ -> V.join)

    let smash ~oracle = join ~oracle:(fun _ -> oracle)

    let read ~oracle (map : Cil_types.typ -> t -> 'a) (reduce : 'a -> 'a -> 'a) =
      let map t v =
        (* debug true "read %a" pretty v; *)
        map t v
      in
      let rec aux offset m =
        debug dread "@[<hv>read at %a in %a@]" TypedOffset.pretty offset pretty m;
        match offset, m with
        | NoOffset t, m ->
          map t m
        | Field (fi, offset'), Struct s
          when s.struct_type.ckey = fi.fcomp.ckey ->
          aux offset' (S.read s.struct_value fi)
        | Field (fi, offset'), Disjunct d
          when d.disj_type.ckey = fi.fcomp.ckey ->
          D.read (aux offset') reduce d.disj_value fi
        | Field (fi, offset'), Union u
          when Cil_datatype.Fieldinfo.equal u.union_field fi ->
          aux offset' u.union_value
        | Index (exp, index, elem_type, offset'), Array a
          when are_typ_compatible a.array_cell_type elem_type ->
          let lindex, uindex = match Option.map Bound.of_exp exp with
            | Some b -> b, b
            | None | exception Bound.UnsupportedBoundExpression ->
              let l, u = Int_val.min_and_max index in
              Bound.of_integer (Option.get l),
              Bound.of_integer (Option.get u) (* TODO: handle None *)
          in
          A.read ~oracle (aux offset') reduce a.array_value lindex uindex
        | _, m -> (* structure mismatch *)
          let r = Raw (raw m) in
          match offset with
          | NoOffset t -> map t r
          | Field (_, offset') | Index (_, _, _, offset') -> aux offset' r
      in
      aux

    let write ~oracle (f : weak:bool -> Cil_types.typ -> t -> t or_bottom) =
      let rec aux ~weak offset m =
        debug dwrite "@[<hv>write at %a from %a" TypedOffset.pretty offset pretty m;
        match offset with
        | NoOffset t ->
          f ~weak t m
        | Field (fi, offset') ->
          if fi.fcomp.cstruct then (* Structures *)
            if Config.disjunctive_invariants () then
              let old = to_disj fi.fcomp m in
              D.write ~oracle (aux ~weak offset') old fi >>-: fun disj_value ->
              Disjunct { disj_type = fi.fcomp ; disj_value }
            else
              let old = to_struct ~oracle fi.fcomp m in
              S.write (aux ~weak offset') old fi >>-: fun struct_value ->
              Struct { struct_type = fi.fcomp; struct_value }
          else (* Unions *)
            let old = match m with
              | Union u when Cil_datatype.Fieldinfo.equal u.union_field fi -> u
              | _ ->
                let b = raw m in
                { union_value = Raw b ; union_field = fi ; union_padding = b }
            in
            aux ~weak offset' old.union_value >>-: fun union_value ->
            Union { old with union_value }
        | Index (exp, index, elem_type, offset') ->
          let lindex, uindex, weak = match Option.map Bound.of_exp exp with
            | Some b -> b, b, weak
            | None | exception Bound.UnsupportedBoundExpression ->
              let l, u = Int_val.min_and_max index in
              let l = Option.get l and u = Option.get u in (* TODO: handle exceptions *)
              Bound.of_integer l, Bound.of_integer u,
              weak || Integer.equal l u
          in
          match m with
          | Array a when are_typ_compatible a.array_cell_type elem_type ->
            A.write ~oracle (aux ~weak offset') a.array_value
              lindex (Bound.succ uindex) >>-: fun array_value ->
            debug dwrite "wrote from previous@.%a@.->%a" A.pretty a.array_value A.pretty array_value;
            Array { a with array_value }
          | _ ->
            let b = raw m in
            aux ~weak offset' (Raw b) >>-: fun new_value ->
            let array_value = A.single b lindex uindex new_value in
            debug dwrite "wrote from raw@.%a" A.pretty array_value;
            Array { array_cell_type = elem_type ; array_value }
      in aux

    let incr_bound ~oracle vi x m = (* TODO: keep subtree when nothing changes *)
      let rec aux = function
        | (Raw _ | Scalar _) as m -> m
        | Struct s -> Struct { s with struct_value = S.map aux s.struct_value }
        | Disjunct d -> Disjunct { d with disj_value = D.map aux d.disj_value }
        | Union u -> Union { u with union_value = aux u.union_value }
        | Array a ->
          let array_value = A.incr_bound ~oracle vi x a.array_value in
          Array { a with array_value=A.map aux array_value }
      in
      let r = aux m in
      (* debug true "bounds updated@.%a@.to%a" pretty m pretty r; *)
      r

    let add_segmentation_bounds ~oracle ~typ bounds =
      let convert_bound exp =
        try
          Some (Bound.of_exp exp)
        with Bound.UnsupportedBoundExpression -> None
      in
      let bounds = List.filter_map convert_bound bounds in
      function
      | (Raw b as m) ->
        begin match bounds with
          | l :: u :: t ->
            let array_value = A.single b l u m in
            let array_value = A.add_segmentation_bounds ~oracle t array_value in
            Array { array_cell_type = typ ; array_value }
          | _ -> m (* Can't build a segmentation with only one bound *)
        end
      | Array a ->
        let array_value = A.add_segmentation_bounds ~oracle bounds a.array_value
        in
        Array { a with array_value }
      | m -> m (* Ignore segmentation hints on non-array *)
  end
  and S : Structures with type submemory = ProtoMemory.t =
    Structures (Config) (ProtoMemory)
  and A : Segmentation with type submemory = ProtoMemory.t =
    Segmentation (Config) (ProtoMemory)
  and D : Disjunction with type submemory = ProtoMemory.t and type structure = S.t =
    Disjunction (Config) (ProtoMemory) (S)

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

  let write' ~oracle ~weak f offset m =
    let f' ~weak typ m =
      `Value (f ~weak typ m)
    in
    Bottom.non_bottom (write ~oracle ~weak f' offset m)

  let set ~oracle ~weak m offset new_v =
    let f ~weak typ m =
      of_value typ (if weak then V.join (to_value typ m) new_v else new_v)
    in
    let r = write' ~oracle ~weak f offset m in
    (* Format.printf "%a <- %a : %a@." TypedOffset.pretty offset V.pretty new_v pretty r; *)
    r

  let join ~oracle m1 m2 =
    let r = join ~oracle m1 m2 in
    (* Format.printf "%a join %a : %a@." pretty m1 pretty m2 pretty r; *)
    r

  let reinforce ~oracle f m offset =
    let f' ~weak typ m =
      if weak
      then `Value m
      else f (to_value typ m) >>-: of_value typ
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
    write' ~oracle ~weak f offset m

  let overwrite ~oracle ~weak dst offset src =
    let f ~weak _typ m =
      if weak then
        smash ~oracle m src
      else
        src
    in
    write' ~oracle ~weak f offset dst

  let segmentation_hint ~oracle m offset bounds =
    let f ~weak:_ typ m =
      add_segmentation_bounds ~oracle ~typ bounds m
    in
    write' ~oracle ~weak:false f offset m
end
