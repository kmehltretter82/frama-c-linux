(*************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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
(*************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Region Memory Model                                                --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types
open Ctypes
open Lang.F
open Sigs
open MemMemory

type primitive = Int of c_int | Float of c_float | Ptr
type kind = Single of primitive | Many of primitive | Garbled

let pp_prim fmt = function
  | Int i -> Ctypes.pp_int fmt i
  | Float f -> Ctypes.pp_float fmt f
  | Ptr -> Format.pp_print_string fmt "ptr"

let pp_kind fmt = function
  | Single p -> pp_prim fmt p
  | Many p -> Format.fprintf fmt "[%a]" pp_prim p
  | Garbled -> Format.pp_print_string fmt "[bytes]"

let tau_of_prim = function
  | Int _ -> Qed.Logic.Int
  | Float f -> Cfloat.tau_of_float f
  | Ptr -> MemAddr.t_addr

(* -------------------------------------------------------------------------- *)
(* --- Region Analysis Proxy                                              --- *)
(* -------------------------------------------------------------------------- *)

module type RegionProxy =
sig
  type region
  module Type : Sigs.Type with type t = region
  val null : unit -> region

  val kind : region -> kind

  val tau_of_region : region -> tau
  val points_to : region -> region option

  val separated : region -> region -> bool
  val included : region -> region -> bool

  val cvar : varinfo -> region option
  val field : region -> fieldinfo -> region option
  val shift : region -> c_object -> region option
  val base_addr : region -> region

  val literal : eid:int -> Cstring.cst -> region option
  val pointer_loc : unit -> region option
  val loc_of_int : unit -> region option

  val id : region -> int
  val of_id : int -> region option

end

(* -------------------------------------------------------------------------- *)
(* --- Underlying Model (Handles Addresses & Garbled)                     --- *)
(* -------------------------------------------------------------------------- *)

module type ModelWithLoader = sig
  include Sigs.Model

  val sizeof : c_object -> term
  val last : sigma -> c_object -> loc -> term

  val frames : c_object -> loc -> chunk -> frame list

  val havoc : c_object -> loc -> length:term -> chunk -> fresh:term -> current:term -> term

  val eqmem_forall : c_object -> loc -> chunk -> term -> term -> var list * pred * pred

  val load_int : sigma -> c_int -> loc -> term
  val load_float : sigma -> c_float -> loc -> term
  val load_pointer : sigma -> typ -> loc -> loc

  val store_int : sigma -> c_int -> loc -> term -> Chunk.t * term
  val store_float : sigma -> c_float -> loc -> term -> Chunk.t * term
  val store_pointer : sigma -> typ -> loc -> term -> Chunk.t * term

  val set_init_atom : sigma -> c_object -> loc -> term -> chunk * term
  val set_init : c_object -> loc -> length:term -> chunk -> current:term -> term
  val is_init_atom : sigma -> c_object -> loc -> term
  val is_init_range : sigma -> c_object -> loc -> term -> pred

  val value_footprint : c_object -> loc -> Sigma.domain
  val init_footprint : c_object -> loc -> Sigma.domain

end

(* -------------------------------------------------------------------------- *)
(* --- Region Memory Model                                                --- *)
(* -------------------------------------------------------------------------- *)

module Make (R:RegionProxy) (M:ModelWithLoader) (*: Sigs.Model*) =
struct

  type region = R.region
  let datatype = "MemRegion.Make"
  (* For projectification. Must be unique among models. *)

  let configure = M.configure
  let configure_ia = M.configure_ia
  let hypotheses = M.hypotheses

  module MChunk = M.Chunk
  module RChunk =
  struct
    let self = "MemRegion.RChunk"

    type mu = Value of primitive | Array of primitive | ValInit | ArrInit
    type t = { mu : mu ; region : R.region }

    let pp_mu fmt = function
      | Value p -> Format.fprintf fmt "µ%a" pp_prim p
      | Array p -> Format.fprintf fmt "µ%a[]" pp_prim p
      | ValInit -> Format.pp_print_string fmt "µinit"
      | ArrInit -> Format.pp_print_string fmt "µinit[]"

    let hash { mu ; region } = Hashtbl.hash (mu, R.Type.hash region)
    let equal a b = Stdlib.(=) a.mu b.mu && R.Type.equal a.region b.region
    let compare a b =
      let cmp = Stdlib.compare a.mu b.mu in
      if cmp <> 0 then cmp else R.Type.compare a.region b.region

    let pretty fmt { mu ; region } =
      Format.fprintf fmt "%a@%03d" pp_mu mu (R.id region)

    let tau_of_chunk { mu } =
      match mu with
      | Value p -> tau_of_prim p
      | ValInit -> Qed.Logic.Bool
      | Array p -> Qed.Logic.Array(MemAddr.t_addr,tau_of_prim p)
      | ArrInit -> Qed.Logic.Array(MemAddr.t_addr,Qed.Logic.Bool)

    let basename_of_chunk { mu } =
      match mu with
      | Value p -> Format.asprintf "V%a" pp_prim p
      | Array p -> Format.asprintf "M%a" pp_prim p
      | ValInit -> "Vinit"
      | ArrInit -> "Minit"

    let is_framed _ = false

  end

  module MHeap = M.Heap
  module MSigma = M.Sigma

  module RHeap = Qed.Collection.Make(RChunk)
  module RSigma = Sigma.Make(RChunk)(RHeap)

  type chunk =
    | M of MChunk.t
    | R of RChunk.t

  let cmap f g (m,r) = (f m, g r)
  let cmap2 f g (m1,r1) (m2,r2) = (f m1 m2, g r1 r2)
  let capply f g (m,r) = function M c -> f m c, r | R c -> m, g r c
  let cmerge f g c (m,r) = match c with M c -> f m c | R c -> g r c

  module Chunk =
  struct
    let self = "MemRegion.Make.Chunk"

    type t = chunk

    let hash = function
      | M c -> 3 * MChunk.hash c
      | R c -> 5 * RChunk.hash c

    let equal ca cb = match ca, cb with
      | M c1, M c2 -> MChunk.equal c1 c2
      | R c1, R c2 -> RChunk.equal c1 c2
      | M _, R _ | R _, M _ -> false

    let compare c1 c2 =
      match c1, c2 with
      | M m1, M m2 -> MChunk.compare m1 m2
      | R r1, R r2 -> RChunk.compare r1 r2
      | M _, R _ -> (-1)
      | R _, M _ -> (+1)

    let pretty fmt = function
      | M c -> MChunk.pretty fmt c
      | R c -> RChunk.pretty fmt c

    let tau_of_chunk = function
      | M c -> MChunk.tau_of_chunk c
      | R c -> RChunk.tau_of_chunk c

    let basename_of_chunk = function
      | M c -> MChunk.basename_of_chunk c
      | R c -> RChunk.basename_of_chunk c

    let is_framed = function
      | M c -> MChunk.is_framed c
      | R c -> RChunk.is_framed c

  end

  module Heap = Qed.Collection.Make(Chunk)

  type sigma = MSigma.t * RSigma.t
  type domain = Heap.Set.t

  module Sigma =
  struct

    type t = sigma
    type chunk = Chunk.t
    module Chunk = Chunk

    let create () : sigma = (MSigma.create (), RSigma.create ())

    let pretty fmt (m,r) =
      Format.fprintf fmt "@[<hv 0>{@[<hv 2>@ %a;@ %a;@]@ }@]"
        MSigma.pretty m
        RSigma.pretty r

    let empty : domain = Heap.Set.empty
    let mem = cmerge MSigma.mem RSigma.mem
    let get = cmerge MSigma.get RSigma.get
    let value = cmerge MSigma.value RSigma.value
    let copy = cmap MSigma.copy RSigma.copy
    let choose = cmap2 MSigma.choose RSigma.choose
    let havoc_chunk = cmap MSigma.havoc_chunk RSigma.havoc_chunk
    let havoc_any ~call = cmap (MSigma.havoc_any ~call) (RSigma.havoc_any ~call)

    let merge (m1,r1) (m2,r2) =
      let m,p1,p2 = MSigma.merge m1 m2 in
      let r,q1,q2 = RSigma.merge r1 r2 in
      (m,r), Passive.union p1 q1, Passive.union p2 q2

    let merge_list l =
      let m,p = MSigma.merge_list @@ List.map fst l in
      let r,q = RSigma.merge_list @@ List.map snd l in
      (m,r), List.map2 Passive.union p q

    let join (m1,r1) (m2,r2) =
      Passive.union (MSigma.join m1 m2) (RSigma.join r1 r2)

    let iter f (m,r) =
      begin
        MSigma.iter (fun c -> f (M c)) m ;
        RSigma.iter (fun c -> f (R c)) r ;
      end

    let iter2 f (m1,r1) (m2,r2) =
      begin
        MSigma.iter2 (fun c -> f (M c)) m1 m2 ;
        RSigma.iter2 (fun c -> f (R c)) r1 r2 ;
      end

    let mdomain d =
      MHeap.Set.fold (fun c s -> Heap.Set.add (M c) s) d Heap.Set.empty
    let rdomain d =
      RHeap.Set.fold (fun c s -> Heap.Set.add (R c) s) d Heap.Set.empty

    let dsplit d =
      let m = ref MHeap.Set.empty in
      let r = ref RHeap.Set.empty in
      Heap.Set.iter
        (function
          | M c -> m := MHeap.Set.add c !m
          | R c -> r := RHeap.Set.add c !r
        ) d ;
      !m, !r

    let assigned ~pre:(m1,r1) ~post:(m2,r2) d =
      let m,r = dsplit d in
      let hm = MSigma.assigned ~pre:m1 ~post:m2 m in
      let hr = RSigma.assigned ~pre:r1 ~post:r2 r in
      Bag.concat hm hr

    let havoc (m,r) d =
      let dm,dr = dsplit d in
      MSigma.havoc m dm, RSigma.havoc r dr

    let remove_chunks (m,r) d =
      let dm,dr = dsplit d in
      MSigma.remove_chunks m dm, RSigma.remove_chunks r dr

    let domain (m,r) =
      Heap.Set.union (mdomain @@ MSigma.domain m) (rdomain @@ RSigma.domain r)

    let writes { pre = (m1,r1) ; post = (m2,r2) } =
      let m = { pre = m1 ; post = m2 } in
      let r = { pre = r1 ; post = r2 } in
      Heap.Set.union (mdomain @@ MSigma.writes m) (rdomain @@ RSigma.writes r)

  end

  (***************************************************************************)
  (* module Region : MemLoader.Module                                       **)
  (***************************************************************************)

  module Region = struct
    module Chunk = Chunk
    module Sigma = Sigma
    let name = "RegionModel"

    type loc =
      | Null
      | Raw of M.loc
      | Loc of M.loc * region

    let make a = function None -> Raw a | Some r -> Loc(a,r)
    let loc = function Null -> M.null | Raw a | Loc(a,_) -> a
    let reg = function Null | Raw _ -> None | Loc(_,r) -> Some r
    let kind = function Null | Raw _ -> Garbled | Loc(_,r) -> R.kind r
    let rid = function Null | Raw _ -> 0 | Loc(_,r) -> R.id r
    let rfold f = function Null | Raw _ -> None | Loc(_,r) -> f r
    let rmap f = function Null | Raw _ -> None | Loc(_,r) -> Some (f r)

    (* ---------------------------------------------------------------------- *)
    (* --- Utilities on locations                                         --- *)
    (* ---------------------------------------------------------------------- *)

    let last sigma ty l = M.last (fst sigma) ty (loc l)
    let pointer_val l = M.pointer_val (loc l)

    let sizeof ty = M.sizeof ty

    let field l fd =
      make (M.field (loc l) fd) (rfold (fun r -> R.field r fd) l)

    let shift l obj ofs =
      make (M.shift (loc l) obj ofs) (rfold (fun r -> R.shift r obj) l)

    let frames ty l c =
      match kind l with
      | Single Ptr | Many Ptr | Garbled ->
        let offset = M.sizeof ty in
        let sizeof = Lang.F.e_one in
        let tau = Chunk.tau_of_chunk c in
        let basename = Chunk.basename_of_chunk c in
        MemMemory.frames ~addr:(pointer_val l) ~offset ~sizeof ~basename tau
      | _ -> []

    let havoc ty l ~length chunk ~fresh ~current =
      match chunk with
      | M c -> M.havoc ty (loc l) ~length c ~fresh ~current
      | R c ->
        match c.mu with
        | Value _ | ValInit -> fresh
        | Array _ | ArrInit -> e_fun f_havoc [fresh;current;pointer_val l;length]

    let eqmem_forall ty l chunk m1 m2 =
      match chunk with
      | M c -> M.eqmem_forall ty (loc l) c m1 m2
      | R c ->
        match c.mu with
        | Value _ | ValInit -> [], p_true, p_equal m1 m2
        | Array _ | ArrInit ->
          let xp = Lang.freshvar ~basename:"b" MemAddr.t_addr in
          let p = e_var xp in
          let n = M.sizeof ty in
          let separated =
            p_call MemAddr.p_separated [p;e_one;pointer_val l;n] in
          let equal = p_equal (e_get m1 p) (e_get m2 p) in
          [xp],separated,equal

    (* ---------------------------------------------------------------------- *)
    (* --- Load                                                           --- *)
    (* ---------------------------------------------------------------------- *)

    let localized action = function
      | Null ->
        Warning.error ~source:"MemRegion"
          "Attempt to %s at NULL" action
      | Raw a ->
        Warning.error ~source:"MemRegion"
          "Attempt to %s without region (%a)" action M.pretty a
      | Loc(l,r) -> l,r

    let check action (p:primitive) (q:primitive) =
      if Stdlib.(<>) p q then
        Warning.error ~source:"MemRegion"
          "Inconsistent %s (%a <> %a)"
          action pp_prim p pp_prim q

    let load_int sigma iota loc : term =
      let l,r = localized "load int" loc in
      match R.kind r with
      | Garbled -> M.load_int (fst sigma) iota l
      | Single p ->
        check "load" p (Int iota) ;
        RSigma.value (snd sigma) { mu = Value p ; region = r }
      | Many p ->
        check "load" p (Int iota) ;
        e_get
          (RSigma.value (snd sigma) { mu = Array p ; region = r})
          (M.pointer_val l)

    let load_float sigma flt loc : term =
      let l,r = localized "load float" loc in
      match R.kind r with
      | Garbled -> M.load_float (fst sigma) flt l
      | Single p ->
        check "load" p (Float flt) ;
        RSigma.value (snd sigma) { mu = Value p ; region = r }
      | Many p ->
        check "load" p (Float flt) ;
        e_get
          (RSigma.value (snd sigma) { mu = Array p ; region = r})
          (M.pointer_val l)

    let load_pointer sigma ty loc : loc =
      let l,r = localized "load float" loc in
      match R.points_to r with
      | None ->
        Warning.error ~source:"MemRegion"
          "Attempt to load pointer without points-to@\n\
           (addr %a, region %a)"
          M.pretty l R.Type.pretty r
      | Some _ as rp ->
        let loc =
          match R.kind r with
          | Garbled -> M.load_pointer (fst sigma) ty l
          | Single p ->
            check "load" p Ptr ;
            M.pointer_loc @@
            RSigma.value (snd sigma) { mu = Value p ; region = r }
          | Many p ->
            check "load" p Ptr ;
            M.pointer_loc @@
            e_get
              (RSigma.value (snd sigma) { mu = Array p ; region = r})
              (M.pointer_val l)
        in make loc rp

    (* ---------------------------------------------------------------------- *)
    (* --- Store                                                          --- *)
    (* ---------------------------------------------------------------------- *)

    let store_int sigma c_int loc v : Chunk.t * term = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.store_int"
            ~effect:"Loc is Null" "Attempt to store_int inside Null"
        in let c, t = M.store_int sigma.Tuple.model c_int M.null v in
        M c, t
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.store_int"
            ~effect:"Loc is Raw" "store_int(Raw %a)" M.pretty repr
        in let c, t = M.store_int sigma.Tuple.model c_int repr v in
        M c, t
      | Loc { repr ; region } ->
        let c = R (B.CVal region) in
        match R.kind region with
        | Many (Int c_int') as k ->
          if compare_c_int c_int c_int' = 0
          then (c, F.e_set (Sigma.value sigma c) (M.pointer_val repr) v)
          else
            let _ = Warning.emit ~severe:false
                ~source:"MemRegion.Region.store_int"
                ~effect:"Int types are not the same"
                "(%a in %a : %a != %a)"
                M.pretty repr R.pretty region pp_kind k Ctypes.pp_int c_int
            in (c, F.e_set (Sigma.value sigma c) (M.pointer_val repr) v)
        | Single (Int c_int') as k ->
          if compare_c_int c_int c_int' = 0
          then (c, v)
          else
            let _ = Warning.emit ~severe:false
                ~source:"MemRegion.Region.store_int"
                ~effect:"Int types are not the same"
                "(%a in %a : %a != %a)"
                M.pretty repr R.pretty region pp_kind k Ctypes.pp_int c_int
            in (c, v)
        | Garbled ->
          let (c', v) = M.store_int sigma.model c_int repr v in
          (M c', v)
        | k ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.store_int"
              ~effect:"Int types are not the same"
              "(%a in %a : %a != %a)"
              M.pretty repr R.pretty region pp_kind k Ctypes.pp_int c_int
          in assert false

    let store_float sigma c_float loc v : Chunk.t * term = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.store_float"
            ~effect:"Loc is Null" "Attempt to store_float inside Null"
        in let c, t = M.store_float sigma.Tuple.model c_float M.null v in
        M c, t
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.store_float"
            ~effect:"Loc is Raw" "store_float(Raw %a)" M.pretty repr
        in let c, t = M.store_float sigma.Tuple.model c_float repr v in
        M c, t
      | Loc { repr ; region } ->
        let c = R (B.CVal region) in
        match R.kind region with
        | Many (Float c_float') as k ->
          if compare_c_float c_float c_float' = 0
          then (c, F.e_set (Sigma.value sigma c) (M.pointer_val repr) v)
          else
            let _ = Warning.emit ~severe:false
                ~source:"MemRegion.Region.store_float"
                ~effect:"Float types are not the same"
                "(%a in %a : %a != %a)"
                M.pretty repr R.pretty region pp_kind k Ctypes.pp_float c_float
            in (c, F.e_set (Sigma.value sigma c) (M.pointer_val repr) v)
        | Single (Float c_float') as k ->
          if compare_c_float c_float c_float' = 0
          then (c, v)
          else
            let _ = Warning.emit ~severe:false
                ~source:"MemRegion.Region.store_float"
                ~effect:"Float types are not the same"
                "(%a in %a : %a != %a)"
                M.pretty repr R.pretty region pp_kind k Ctypes.pp_float c_float
            in (c, v)
        | Garbled ->
          let (c, t) = M.store_float sigma.Tuple.model c_float repr v in
          (M c, t)
        | k ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.store_float"
              ~effect:"Float types are not the same"
              "(%a in %a : %a != %a)"
              M.pretty repr R.pretty region pp_kind k Ctypes.pp_float c_float
          in assert false

    let store_pointer sigma ty loc v : Chunk.t * term = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.store_pointer"
            ~effect:"Loc is Null" "Attempt to store_pointer inside Null"
        in let c, t = M.store_pointer sigma.Tuple.model ty M.null v in
        M c, t
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.store_pointer"
            ~effect:"Loc is Raw" "store_pointer(Raw %a : *%a)"
            M.pretty repr Printer.pp_typ ty
        in let c, t = M.store_pointer sigma.Tuple.model ty repr v in
        M c, t
      | Loc { repr ; region } ->
        let c = R (B.CVal region) in
        match R.kind region with
        | Many (Ptr) ->
          c, F.e_set (Sigma.value sigma c) (M.pointer_val repr) v
        | Single (Ptr) -> c,v
        | Garbled ->
          let (c, repr) = M.store_pointer sigma.Tuple.model ty repr v in
          (M c, repr)
        | k ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.store_pointer"
              ~effect:"This is not a region with pointer type"
              "(%a in %a : %a != *%a)"
              M.pretty repr R.pretty region pp_kind k Printer.pp_typ ty
          in assert false

    (* ---------------------------------------------------------------------- *)
    (* --- Init                                                           --- *)
    (* ---------------------------------------------------------------------- *)

    let set_init_atom sigma ty loc v = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.set_init_atom"
            ~effect:"Loc is Null" "Attempt to set_init_atom with Null"
        in let (c, t) = M.set_init_atom sigma.Tuple.model ty M.null v in
        (M c, t)
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.set_init_atom"
            ~effect:"Loc is Raw" "set_init_atom(Raw %a <- %a)"
            M.pretty repr QED.pretty v
        in let (c, t) = M.set_init_atom sigma.Tuple.model ty repr v in
        (M c, t)
      | Loc { repr ; region }->
        match R.kind region with
        | Garbled ->
          let (c, t) = M.set_init_atom sigma.Tuple.model ty repr v in
          (M c, t)
        | Single _-> R (B.CInit region), v
        | Many _ ->
          let c = R (B.CInit region) in
          c, F.e_set (Sigma.value sigma c) (M.pointer_val repr) v

    let is_init_atom sigma ty loc : term = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.is_init_atom"
            ~effect:"Loc is Null" "is_init_atom(Null)"
        in M.is_init_atom sigma.Tuple.model ty M.null
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.is_init_atom"
            ~effect:"Loc is Raw" "is_init_atom(Raw %a)"
            M.pretty repr
        in M.is_init_atom sigma.Tuple.model ty repr
      | Loc { repr ; region } ->
        let c = R (B.CInit region) in
        match R.kind region with
        | Garbled -> M.is_init_atom sigma.Tuple.model ty repr
        | Many _ -> F.e_get (Sigma.value sigma c) @@ M.pointer_val repr
        | Single _ -> Sigma.value sigma c

    let is_init_range sigma ty loc length : pred = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.is_init_range"
            ~effect:"Loc is Null" "is_init_range(Null)"
        in M.is_init_range sigma.Tuple.model ty M.null length
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.is_init_range"
            ~effect:"Loc is Raw" "is_init_range(%a, ty=%a, length=%a)"
            M.pretty repr Ctypes.pp_object ty QED.pretty length
        in M.is_init_range sigma.Tuple.model ty repr length
      | Loc { repr ; region } ->
        match R.kind region with
        | Garbled -> M.is_init_range sigma.Tuple.model ty repr length
        | Many _ ->
          let c = R (B.CInit region) in
          let n = F.e_mul (M.sizeof ty) length in
          F.p_call p_is_init_r [Sigma.value sigma c;M.pointer_val repr;n]
        | Single _ as k ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.is_init_range"
              ~effect:"Region is Single kind" "is_init_range(%a in %a : %a, ty=%a, length=%a)"
              M.pretty repr R.pretty region pp_kind k
              Ctypes.pp_object ty QED.pretty length
          in (* TODO *) assert false


    let set_init ty loc ~length chunk ~current : term = match loc, chunk with
      | Null, M c ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.set_init"
            ~effect:"Loc is Null" "set_init(Null)"
        in M.set_init ty M.null ~length c ~current
      | Null, Chunk.CRegion _ ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.set_init"
            ~effect:"Loc is Null" "set_init(Null) and Chunk is Region"
        in assert false
      | Raw { repr }, M c ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.set_init"
            ~effect:"Loc is Null" "set_init(Raw %a)"
            M.pretty repr
        in M.set_init ty repr ~length c ~current
      | Raw { repr }, Chunk.CRegion _ ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.set_init"
            ~effect:"Loc is Null" "set_init(Raw %a) and Chunk is Region"
            M.pretty repr
        in assert false
      | Loc { repr }, M c -> M.set_init ty repr ~length c ~current
      | Loc { repr ; region }, Chunk.CRegion c ->
        match R.kind region, c with
        | Garbled, ( B.CVal _ | B.CInit _| B.CGhost _) ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.set_init"
              ~effect:"Garbled is not associated to low memory model"
              "set_init(%a in %a : Garbled)"
              M.pretty repr R.pretty region
          in assert false
        | Many _, _ ->
          let n = F.e_mul (M.sizeof ty) length in
          F.e_fun f_set_init [current;M.pointer_val repr;n]
        | Single _, _ ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.set_init"
              ~effect:"Single is not supported"
              "set_init(%a in %a : Single)"
              M.pretty repr R.pretty region
          in (* TODO *) assert false


    (* ---------------------------------------------------------------------- *)
    (* --- Footprints                                                     --- *)
    (* ---------------------------------------------------------------------- *)

    let rec value_footprint ty loc = match loc with
      | Null -> Sigma.empty
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.value_footprint"
            ~effect:"Loc is Raw"
            "value_footprint(Raw %a : %a)"
            M.pretty repr Ctypes.pp_object ty
        in
        let model = M.value_footprint ty repr in
        Sigma.to_domain Tuple.{ model ; region = RegionSigma.empty }
      | Loc { repr ; region } ->
        match R.kind region, ty with
        | Garbled, (C_int _ | C_float _ | C_pointer _) ->
          let model = M.value_footprint ty repr in
          Sigma.to_domain Tuple.{ model ; region = RegionSigma.empty }
        | (Many (Int   _) | Single (Int   _)), C_int _
        | (Many (Float _) | Single (Float _)), C_float _
        | (Many (Ptr    ) | Single (Ptr    )), C_pointer _->
          Heap.Set.singleton (R (B.CVal region))
        | (Many _ | Single _) as k, (C_int _ | C_float _ | C_pointer _) ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.value_footprint"
              ~effect:"Type is not the same in chunk and in argument"
              "value_footprint(%a : %a in %a : %a)"
              M.pretty repr Ctypes.pp_object ty R.pretty region pp_kind k
          in Heap.Set.singleton @@ R (B.CVal region)
        | _, C_comp { cfields } ->
          let none = Heap.Set.empty in
          let f_fold acc fd =
            Heap.Set.union acc
            @@ value_footprint (Ctypes.object_of fd.ftype)
            @@ field loc fd
          in let some l_fields =
               List.fold_left f_fold Heap.Set.empty l_fields
          in Option.fold ~none ~some cfields
        | _, C_array { arr_element } ->
          let ty = object_of arr_element in
          value_footprint ty (shift loc ty e_zero)

    let rec init_footprint ty loc = match loc with
      | Null -> Sigma.empty
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.init_footprint"
            ~effect:"Loc is Raw"
            "init_footprint(Raw %a : %a)"
            M.pretty repr Ctypes.pp_object ty
        in let model = M.init_footprint ty repr in
        Sigma.to_domain Tuple.{ model ; region = RegionSigma.empty }
      | Loc { repr ; region } ->
        match R.kind region, ty with
        | Garbled, (C_int _ | C_float _ | C_pointer _) ->
          let model =  M.init_footprint ty repr in
          Sigma.to_domain Tuple.{ model ; region = RegionSigma.empty }
        | (Many (Int   _) | Single (Int   _)), C_int _
        | (Many (Float _) | Single (Float _)), C_float _
        | (Many (Ptr    ) | Single (Ptr    )), C_pointer _->
          Heap.Set.singleton @@ R (B.CInit region)
        | (Many _ | Single _) as k, (C_int _ | C_float _ | C_pointer _) ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.init_footprint"
              ~effect:"Type is not the same in chunk and in argument"
              "init_footprint(%a : %a in %a : %a)"
              M.pretty repr Ctypes.pp_object ty R.pretty region pp_kind k
          in Heap.Set.singleton @@ R (B.CInit region)
        | _, C_comp { cfields } ->
          let none = Heap.Set.empty in
          let f_fold acc fd =
            Heap.Set.union acc
            @@ init_footprint (Ctypes.object_of fd.ftype)
            @@ field loc fd
          in let some l_fields = List.fold_left f_fold Heap.Set.empty l_fields
          in Option.fold ~none ~some cfields
        | _, C_array { arr_element } ->
          let ty = object_of arr_element in
          init_footprint ty (shift loc ty e_zero)

  end

  type loc = Region.loc
  type domain = Sigma.domain
  type chunk = Chunk.t
  type segment = loc rloc



  (***************************************************************************)
  module LOADER = MemLoader.Make(Region)
  (*****************************************************************************)

  let load = LOADER.load
  let load_init = LOADER.load_init
  let stored = LOADER.stored
  let stored_init = LOADER.stored_init
  let copied = LOADER.copied
  let copied_init = LOADER.copied_init
  let initialized = LOADER.initialized
  let domain = LOADER.domain

  let assigned seq ty sloc = match sloc with
    | Sloc (Region.Null) | Sarray (Region.Null,_,_)
    | Srange (Region.Null,_,_,_) | Sdescr (_,Region.Null,_) ->
      LOADER.assigned seq ty sloc
    | Sloc (Region.Raw _) | Sarray (Region.Raw _,_,_)
    | Srange (Region.Raw _,_,_,_) | Sdescr (_,Region.Raw _,_) ->
      LOADER.assigned seq ty sloc
    | _ ->
      (* Maintain always initialized values initialized *)
      let region = match sloc with
        | Sloc (Region.Loc loc) | Sarray (Region.Loc loc, _, _)
        | Srange (Region.Loc loc, _, _, _)
        | Sdescr (_, Region.Loc loc, _) -> loc.region
        | Sloc (Region.Null|Region.Raw _)
        | Sarray ((Region.Null|Region.Raw _),_,_)
        | Srange ((Region.Null|Region.Raw _),_,_,_)
        | Sdescr (_,(Region.Null|Region.Raw _),_) -> assert false
      in
      Assert (MemMemory.cinits
              @@ Sigma.value seq.post @@ R (B.CInit region)) ::
      LOADER.assigned seq ty sloc

  (* {2 Reversing the Model} *)

  type state = M.state

  let state sigma = M.state sigma.Tuple.model

  let lookup s e = M.lookup s e

  let updates = M.updates

  let apply = M.apply

  let iter = M.iter

  let pretty fmt = function
    | Region.Null -> Format.fprintf fmt "NULL"
    | Region.Raw { repr } -> Format.fprintf fmt "{ Raw %a }" M.pretty repr
    | Region.Loc { repr ; region } ->
      Format.fprintf fmt "{ %a in %a }"
        M.pretty repr R.pretty region


  (* {2 Memory Model API} *)

  let vars = function
    | Region.Null -> Vars.empty
    | Region.Raw { repr } | Region.Loc { repr } -> M.vars repr
  (* Return the logic variables from which the given location depend on. *)

  let occurs var = function
    | Region.Null -> false
    | Region.Raw {repr } | Region.Loc { repr } -> M.occurs var repr
  (* Test if a location depend on a given logic variable *)

  let null = Region.Null
  (* Return the location of the null pointer *)

  let literal ~eid:eid name =
    let repr = M.literal ~eid name in
    match R.literal ~eid name with
    | None -> Region.Raw { repr }
    | Some region -> Region.Loc { repr ; region }
  (* Return the memory location of a constant string,
      the id is a unique identifier. *)

  let cvar var =
    match R.cvar var with
    | None ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.cvar"
          ~effect:"No region for this var" "%a"
          Printer.pp_varinfo var
      in Region.Raw { repr = M.cvar var }
    | Some region -> Region.Loc { repr = M.cvar var ; region }
  (* Return the location of a C variable. *)

  let pointer_loc term =
    if QED.equal term @@ M.pointer_val M.null
    then Region.Null
    else let repr = M.pointer_loc term in
      match R.pointer_loc () with
      | None -> Region.Raw { repr }
      | Some region -> Region.Loc { repr ; region }
  (* Interpret an address value (a pointer) as an abstract location.
      Might fail on memory models not supporting pointers. *)

  let pointer_val = function
    | Region.Null -> M.pointer_val M.null
    | Region.Raw { repr } ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.pointer_val"
          ~effect:"No region for this loc" "%a" M.pretty repr
      in M.pointer_val repr
    | Region.Loc { repr } -> M.pointer_val repr
  (* Return the adress value (a pointer) of an abstract location.
      Might fail on memory models not capable of representing pointers. *)

  let field loc fieldinfo = match loc with
    | Region.Null ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.field"
          ~effect:"Loc is NULL"
          "NULL.(%a)" Printer.pp_field fieldinfo
      in Region.Null
    | Region.Raw { repr } ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.field"
          ~effect:"Loc is Raw"
          "(%a).(%a)" M.pretty repr Printer.pp_field fieldinfo
      in Region.Raw { repr = M.field repr fieldinfo }
    | Region.Loc { repr ; region } ->
      match R.field region fieldinfo with
      | None ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.field"
            ~effect:"No region for this field"
            "(%a in %a).(%a in no region)"
            M.pretty repr R.pretty region Printer.pp_field fieldinfo
        in Region.Raw { repr = M.field repr fieldinfo }
      | Some region -> Region.Loc { repr = M.field repr fieldinfo ; region }
  (* Return the memory location obtained by field access from a given
      memory location. *)

  let shift loc ty term = match loc with
    | Region.Null ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.shift"
          ~effect:"Loc is NULL"
          "NULL.[%a : %a]" QED.pretty term Ctypes.pp_object ty
      in Region.Null
    | Region.Raw { repr } ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.shift"
          ~effect:"Loc is Raw"
          "(%a).[%a : %a]"
          M.pretty repr QED.pretty term Ctypes.pp_object ty
      in Region.Raw { repr = M.shift repr ty term }
    | Region.Loc { repr ; region } ->
      match R.shift region ty term with
      | None ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.shift"
            ~effect:"Loc is Raw"
            "(%a in %a).[%a : %a] in no region"
            M.pretty repr R.pretty region QED.pretty term Ctypes.pp_object ty
        in Region.Raw { repr = M.shift repr ty term }
      | Some region -> Region.Loc { repr = M.shift repr ty term ; region }
  (* Return the memory location obtained by array access at an index
      represented by the given {!term}. The element of the array are of
      the given {!c_object} type. *)

  let base_addr  = function
    | Region.Null -> Region.Null
    | Region.Raw { repr } ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.base_addr"
          ~effect:"Loc is Raw" "base_addr(%a)" M.pretty repr
      in Region.Raw { repr = M.base_addr repr }
    | Region.Loc { repr ; region } ->
      Region.Loc { repr = M.base_addr repr ; region = R.base_addr region }
  (* Return the memory location of the base address of a given memory
      location. *)

  let base_offset = function
    | Region.Null -> M.base_offset M.null
    | Region.Raw { repr } ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.base_offset"
          ~effect:"Loc is Raw" "base_offset(%a)" M.pretty repr
      in M.base_offset repr
    | Region.Loc { repr } -> M.base_offset repr
  (* Return the offset of the location, in bytes, from its base_addr. *)

  let block_length sigma ty  = function
    | Region.Null -> M.block_length sigma.Tuple.model ty M.null
    | Region.Raw { repr } ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.block_length"
          ~effect:"Loc is Raw" "block_length(%a)" M.pretty repr
      in M.block_length sigma.Tuple.model ty repr
    | Region.Loc { repr } -> M.block_length sigma.Tuple.model ty repr
  (*  Returns the length (in bytes) of the allocated block containing
       the given location. *)

  let cast objs = function
    | Region.Null -> Region.Null
    | Region.Raw { repr } ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.cast"
          ~effect:"Loc is NULL" "NULL=%a" M.pretty repr
      in Region.Raw { repr = M.cast objs repr }
    | Region.Loc loc -> Region.Loc { loc with repr = M.cast objs loc.repr }
  (* Cast a memory location into another memory location.
      For [cast ty loc] the cast is done from [ty.pre] to [ty.post].
      Might fail on memory models not supporting pointer casts. *)

  let loc_of_int ty term =
    if QED.equal term @@ M.pointer_val M.null
    then Region.Null
    else match R.loc_of_int () with
      | None -> Region.Raw { repr = M.loc_of_int ty term }
      | Some region -> Region.Loc { repr = M.loc_of_int ty term ; region }

  let int_of_loc c_int = function
    | Region.Null -> M.int_of_loc c_int M.null
    | Region.Raw { repr } ->
      let _ = Warning.emit ~severe:false ~source:"MemRegion.int_of_loc"
          ~effect:"Loc is Raw" "NULL=%a" M.pretty repr
      in M.int_of_loc c_int repr
    | Region.Loc { repr } -> M.int_of_loc c_int repr
  (* Cast a memory location into its absolute memory address,
      given as an integer with the given C-type. *)

  let is_null = function
    | Region.Null -> p_true
    | Region.Raw { repr } | Region.Loc { repr } -> M.is_null repr
  (* Return the formula that check if a given location is null *)

  let get_repr = function
    | Region.Null -> M.null
    | Region.Raw { repr } -> repr
    | Region.Loc { repr } -> repr

  let loc_eq loc_a loc_b = M.loc_eq (get_repr loc_a) (get_repr loc_b)
  let loc_lt loc_a loc_b = M.loc_lt (get_repr loc_a) (get_repr loc_b)
  let loc_neq loc_a loc_b =  M.loc_neq (get_repr loc_a) (get_repr loc_b)
  let loc_leq loc_a loc_b =  M.loc_leq (get_repr loc_a) (get_repr loc_b)
  (* Memory location comparisons *)

  let loc_diff ty loc_a loc_b =  M.loc_diff ty (get_repr loc_a) (get_repr loc_b)
  (* Compute the length in bytes between two memory locations *)

  let get_rloc = function
    | Rloc (ty, Region.Null) -> Rloc (ty, M.null)
    | Rloc (ty, Region.Raw { repr }) -> Rloc (ty, repr)
    | Rloc (ty, Region.Loc loc) ->
      Rloc (ty, loc.repr)
    | Rrange (Region.Null, ty, inf, sup) ->
      Rrange (M.null, ty, inf, sup)
    | Rrange (Region.Raw { repr }, ty, inf, sup) ->
      Rrange (repr, ty, inf, sup)
    | Rrange (Region.Loc loc, ty, inf, sup) ->
      Rrange (loc.repr, ty, inf, sup)


  let get_rloc_region = function
    | Rloc (ty, loc) ->
      Rloc (ty, (match loc with Region.Null -> M.null
                              | Region.Raw { repr } | Region.Loc { repr } -> repr)),
      (match loc with Region.Null | Region.Raw _ -> None
                    | Region.Loc { region } -> Some region)
    | Rrange (loc, ty, inf, sup) ->
      Rrange ((match loc with Region.Null -> M.null
                            | Region.Raw { repr } | Region.Loc { repr } -> repr), ty, inf, sup),
      (match loc with Region.Null | Region.Raw _ -> None
                    | Region.Loc { region } -> Some region)


  let valid sigma acs (rloc : loc rloc) =
    M.valid sigma.Tuple.model acs @@ get_rloc rloc
  (* Return the formula that tests if a memory state is valid
      (according to {!acs}) in the given memory state at the given
      segment.
  *)

  let frame sigma =
    let region_frame sigma = function
      | B.CInit region ->
        MemMemory.cinits @@ Sigma.value sigma @@ Chunk.CRegion (B.CInit region)
      | B.CVal region | B.CGhost region ->  match R.kind region with
        | Many Ptr | Single Ptr ->
          MemMemory.framed @@ Sigma.value sigma @@ Chunk.CRegion (B.CVal region)
        | Garbled | Many (Int _ | Float _)
        | Single (Int _ | Float _) -> p_true
    in
    RegionSigma.Chunk.Set.fold
      (fun c l -> region_frame sigma c :: l)
      (RegionSigma.domain sigma.region)
    @@ M.frame sigma.model
  (* Assert the memory is a proper heap state preceeding the function
      entry point. *)

  let alloc (sigma:sigma) vars =
    if vars = [] then sigma
    else { sigma with model = M.alloc sigma.model vars }
  (* Allocates new chunk for the validity of variables. *)

  let invalid (sigma:sigma) rloc = M.invalid sigma.model (get_rloc rloc)
  (* Returns the formula that tests if the entire memory is invalid
      for write access. *)

  let scope (s:sigma sequence) scope vars =
    let m_sigma = { pre = s.pre.model ; post = s.post.model } in
    M.scope m_sigma scope vars
  (* Manage the scope of variables.  Returns the updated memory model
      and hypotheses modeling the new validity-scope of the variables. *)

  let global (sigma:sigma) p = M.global sigma.model p
  (* Given a pointer value [p], assumes this pointer [p] (when valid)
      is allocated outside the function frame under analysis. This means
      separated from the formals and locals of the function. *)

  let included (rloc1 : segment) (rloc2 : segment) =
    let (rl1, region1) = get_rloc_region rloc1 in
    let (rl2, region2) = get_rloc_region rloc2 in
    match region1, region2 with
    | None, _ -> M.included rl1 rl2
    | _, None -> p_false
    | Some region1, Some region2 ->
      if R.separated region1 region2 then p_false
      else M.included rl1 rl2

  let separated (rloc1 : segment) (rloc2 : segment) =
    let (rl1, region1) = get_rloc_region rloc1 in
    let (rl2, region2) = get_rloc_region rloc2 in
    match region1, region2 with
    | None, _ | _, None -> M.separated rl1 rl2
    | Some region1, Some region2 ->
      if R.separated region1 region2 then p_true
      else M.separated rl1 rl2

  let is_well_formed_chunk sigma chunk = match chunk with
    | M _ | Chunk.CRegion (B.CInit _)
    | Chunk.CRegion (B.CGhost _) -> p_true
    | Chunk.CRegion (B.CVal region) -> match R.kind region with
      | Garbled -> p_true
      | Many (Float _ | Ptr )
      | Single (Float _ | Ptr ) -> p_true
      | Many (Int cint) ->
        let l = Lang.freshvar ~basename:"l" (Lang.t_addr()) in
        let m = Sigma.value sigma chunk in
        p_forall [l] (Cint.range cint (F.e_get m (e_var l)))
      | Single (Int cint) ->
        Cint.range cint @@ Sigma.value sigma chunk

  let is_well_formed sigma =
    p_conj @@
    Sigma.Chunk.Set.fold
      (fun c l -> is_well_formed_chunk sigma c :: l)
      (Sigma.domain sigma)
      [M.is_well_formed sigma.model]

end
