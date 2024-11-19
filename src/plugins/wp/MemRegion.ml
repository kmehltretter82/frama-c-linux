(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
(**************************************************************************)

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
  val id : region -> int
  val of_id : int -> region option
  val kind : region -> kind
  val name : region -> string option
  val cvar : varinfo -> region option
  val field : region -> fieldinfo -> region option
  val shift : region -> c_object -> region option
  val points_to : region -> region option
  val literal : eid:int -> Cstring.cst -> region option
  val separated : region -> region -> bool
  val included : region -> region -> bool
  val footprint : region -> region list
end

(* -------------------------------------------------------------------------- *)
(* --- Underlying Model (Handles Addresses & Garbled)                     --- *)
(* -------------------------------------------------------------------------- *)

module type ModelWithLoader = sig
  include Sigs.Model
  include Sigs.Model
  val sizeof : c_object -> term

  val last : sigma -> c_object -> loc -> term
  val frames : c_object -> loc -> chunk -> frame list

  val havoc : c_object -> loc -> length:term -> chunk -> fresh:term -> current:term -> term
  val memcpy : c_object -> lsrc:loc -> ldst:loc -> length:term ->
    chunk -> msrc:term -> mdst:term -> term

  val eqmem_forall : c_object -> loc -> chunk -> term -> term -> var list * pred * pred

  val load_int : sigma -> c_int -> loc -> term
  val load_float : sigma -> c_float -> loc -> term
  val load_pointer : sigma -> typ -> loc -> loc

  val store_int : sigma -> c_int -> loc -> term -> chunk * term
  val store_float : sigma -> c_float -> loc -> term -> chunk * term
  val store_pointer : sigma -> typ -> loc -> term -> chunk * term

  val set_init_atom : sigma -> c_object -> loc -> term -> chunk * term
  val set_init : c_object -> loc -> length:term -> chunk -> current:term -> term
  val is_init_atom : sigma -> c_object -> loc -> term
  val is_init_range : sigma -> c_object -> loc -> term -> pred

  val value_footprint : c_object -> loc -> domain
  val init_footprint : c_object -> loc -> domain
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

    let basename_of_chunk { mu ; region } =
      match mu with
      | ValInit -> "Vinit"
      | ArrInit -> "Minit"
      | Array p -> Format.asprintf "M%a" pp_prim p
      | Value p ->
        match R.name region with
        | Some a -> a
        | None -> Format.asprintf "V%a" pp_prim p

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
  let cmerge f g (m,r) = function M c -> f m c | R c -> g r c
  let mseq { pre ; post } = { pre = fst pre ; post = fst post }
  let rseq { pre ; post } = { pre = snd pre ; post = snd post }

  module Chunk : Sigs.Chunk with type t = chunk =
  struct
    type t = chunk
    let self = "Wp.MemRegion.Self"
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
  module Domain = Heap.Set

  type sigma = MSigma.t * RSigma.t
  type domain = Domain.t

  module Sigma =
  struct

    type t = sigma
    type chunk = Chunk.t
    module Chunk = Heap

    type domain = Domain.t

    let create () : t = (MSigma.create (), RSigma.create ())

    let pretty fmt (m,r) =
      Format.fprintf fmt "@[<hv 0>{@[<hv 2>@ %a;@ %a;@]@ }@]"
        MSigma.pretty m
        RSigma.pretty r

    let empty : domain = Domain.empty
    let union = Domain.union
    let mem = cmerge MSigma.mem RSigma.mem
    let get = cmerge MSigma.get RSigma.get
    let value = cmerge MSigma.value RSigma.value
    let copy = cmap MSigma.copy RSigma.copy
    let choose = cmap2 MSigma.choose RSigma.choose
    let havoc_chunk = capply MSigma.havoc_chunk RSigma.havoc_chunk
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
      MHeap.Set.fold (fun c s -> Domain.add (M c) s) d Domain.empty
    let rdomain d =
      RHeap.Set.fold (fun c s -> Domain.add (R c) s) d Domain.empty

    let dsplit d =
      let m = ref MHeap.Set.empty in
      let r = ref RHeap.Set.empty in
      Domain.iter
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
      union (mdomain @@ MSigma.domain m) (rdomain @@ RSigma.domain r)

    let writes (s : sigma sequence) =
      union
        (mdomain @@ MSigma.writes @@ mseq s)
        (rdomain @@ RSigma.writes @@ rseq s)

  end

  (* -------------------------------------------------------------------------- *)
  (* --- Region Loader                                                         --- *)
  (* -------------------------------------------------------------------------- *)

  module Loader =
  struct
    let name = "MemRegion.Loader"

    module Chunk = Chunk
    module Sigma = Sigma

    type loc =
      | Null
      | Raw of M.loc
      | Loc of M.loc * region

    let make a = function None -> Raw a | Some r -> Loc(a,r)
    let loc = function Null -> M.null | Raw a | Loc(a,_) -> a
    let reg = function Null | Raw _ -> None | Loc(_,r) -> Some r
    let kind = function Null | Raw _ -> Garbled | Loc(_,r) -> R.kind r
    let rfold f = function Null | Raw _ -> None | Loc(_,r) -> f r

    (* ---------------------------------------------------------------------- *)
    (* --- Utilities on locations                                         --- *)
    (* ---------------------------------------------------------------------- *)

    let last sigma ty l = M.last (fst sigma) ty (loc l)

    let to_addr l = M.pointer_val (loc l)

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
        MemMemory.frames ~addr:(to_addr l) ~offset ~sizeof ~basename tau
      | _ -> []

    let havoc ty l ~length chunk ~fresh ~current =
      match chunk with
      | M c -> M.havoc ty (loc l) ~length c ~fresh ~current
      | R c ->
        match c.mu with
        | Value _ | ValInit -> fresh
        | Array _ | ArrInit -> e_fun f_havoc [fresh;current;to_addr l;length]

    let memcpy ty ~lsrc ~ldst ~length chunk ~msrc ~mdst =
      match chunk with
      | M c ->
        M.memcpy ty ~lsrc:(loc lsrc) ~ldst:(loc ldst) ~length c ~msrc ~mdst
      | R c ->
        match c.mu with
        | Value _ | ValInit -> msrc
        | Array _ | ArrInit ->
          e_fun f_memcpy [mdst;msrc;to_addr ldst;to_addr lsrc;length]

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
            p_call MemAddr.p_separated [p;e_one;to_addr l;n] in
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

    let to_region_pointer l =
      let l,r = localized "loader" l in R.id r, M.pointer_val l

    let of_region_pointer r _ t =
      make (M.pointer_loc t) (R.of_id r)

    let check_access action (p:primitive) (q:primitive) =
      if Stdlib.(<>) p q then
        Warning.error ~source:"MemRegion"
          "Inconsistent %s (%a <> %a)"
          action pp_prim p pp_prim q

    let load_int sigma iota loc : term =
      let l,r = localized "load int" loc in
      match R.kind r with
      | Garbled -> M.load_int (fst sigma) iota l
      | Single p ->
        check_access "load" p (Int iota) ;
        RSigma.value (snd sigma) { mu = Value p ; region = r }
      | Many p ->
        check_access "load" p (Int iota) ;
        e_get
          (RSigma.value (snd sigma) { mu = Array p ; region = r})
          (M.pointer_val l)

    let load_float sigma flt loc : term =
      let l,r = localized "load float" loc in
      match R.kind r with
      | Garbled -> M.load_float (fst sigma) flt l
      | Single p ->
        check_access "load" p (Float flt) ;
        RSigma.value (snd sigma) { mu = Value p ; region = r }
      | Many p ->
        check_access "load" p (Float flt) ;
        e_get
          (RSigma.value (snd sigma) { mu = Array p ; region = r})
          (M.pointer_val l)

    let load_pointer sigma ty loc : loc =
      let l,r = localized "load pointer" loc in
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
            check_access "load" p Ptr ;
            M.pointer_loc @@
            RSigma.value (snd sigma) { mu = Value p ; region = r }
          | Many p ->
            check_access "load" p Ptr ;
            M.pointer_loc @@
            e_get
              (RSigma.value (snd sigma) { mu = Array p ; region = r})
              (M.pointer_val l)
        in make loc rp

    (* ---------------------------------------------------------------------- *)
    (* --- Store                                                          --- *)
    (* ---------------------------------------------------------------------- *)

    let store_int sigma iota loc v : Chunk.t * term =
      let l,r = localized "store int" loc in
      match R.kind r with
      | Garbled ->
        let c, m = M.store_int (fst sigma) iota l v in M c, m
      | Single p ->
        check_access "store" p (Int iota) ;
        R { mu = Value p ; region = r }, v
      | Many p ->
        check_access "store" p (Int iota) ;
        let rc = RChunk.{ mu = Array p ; region = r } in
        R rc, e_set (RSigma.value (snd sigma) rc) (M.pointer_val l) v

    let store_float sigma flt loc v : Chunk.t * term =
      let l,r = localized "store float" loc in
      match R.kind r with
      | Garbled ->
        let c,m = M.store_float (fst sigma) flt l v in M c, m
      | Single p ->
        check_access "store" p (Float flt) ;
        R { mu = Value p ; region = r }, v
      | Many p ->
        check_access "store" p (Float flt) ;
        let rc = RChunk.{ mu = Array p ; region = r } in
        R rc, e_set (RSigma.value (snd sigma) rc) (M.pointer_val l) v

    let store_pointer sigma ty loc v : Chunk.t * term =
      let l,r = localized "store pointer" loc in
      match R.kind r with
      | Garbled ->
        let c,m = M.store_pointer (fst sigma) ty l v in M c, m
      | Single p ->
        check_access "store" p Ptr ;
        R { mu = Value p ; region = r }, v
      | Many p ->
        check_access "store" p Ptr ;
        let rc = RChunk.{ mu = Array p ; region = r } in
        R rc, e_set (RSigma.value (snd sigma) rc) (M.pointer_val l) v

    (* ---------------------------------------------------------------------- *)
    (* --- Init                                                           --- *)
    (* ---------------------------------------------------------------------- *)

    let is_init_atom sigma ty loc : term =
      let l,r = localized "init atom" loc in
      match R.kind r with
      | Garbled -> M.is_init_atom (fst sigma) ty l
      | Single _-> RSigma.value (snd sigma) { mu = ValInit ; region = r }
      | Many _ ->
        e_get
          (RSigma.value (snd sigma) { mu = ArrInit ; region = r })
          (M.pointer_val l)

    let set_init_atom sigma ty loc v : Chunk.t * term =
      let l,r = localized "init atom" loc in
      match R.kind r with
      | Garbled ->
        let c,m = M.set_init_atom (fst sigma) ty l v in M c, m
      | Single _-> R { mu = ValInit ; region = r }, v
      | Many _ ->
        let rc = RChunk.{ mu = ArrInit ; region = r } in
        R rc, e_set (RSigma.value (snd sigma) rc) (M.pointer_val l) v

    let is_init_range sigma ty loc length : pred =
      let l,r = localized "init atom" loc in
      match R.kind r with
      | Garbled -> M.is_init_range (fst sigma) ty l length
      | Single _ ->
        Lang.F.p_bool @@ RSigma.value (snd sigma) { mu = ValInit ; region = r }
      | Many _ ->
        let map = RSigma.value (snd sigma) { mu = ArrInit ; region = r } in
        let size = e_mul (M.sizeof ty) length in
        p_call p_is_init_r [map;M.pointer_val l;size]


    let set_init ty loc ~length chunk ~current : term =
      let l,r = localized "init atom" loc in
      match R.kind r, chunk with
      | Garbled, M c -> M.set_init ty l ~length c ~current
      | Garbled, R _ -> assert false
      | Single _, _ -> e_true
      | Many _ , _ ->
        let size = e_mul (M.sizeof ty) length in
        e_fun f_set_init [current;M.pointer_val l;size]

    (* ---------------------------------------------------------------------- *)
    (* --- Footprints                                                     --- *)
    (* ---------------------------------------------------------------------- *)

    let mfootprint ~value obj l =
      if value
      then M.value_footprint obj l
      else M.init_footprint obj l

    let rec footprint ~value obj loc = match loc with
      | Null  -> Sigma.mdomain @@ mfootprint ~value obj M.null
      | Raw l -> Sigma.mdomain @@ mfootprint ~value obj l
      | Loc(l,r) ->
        match obj with
        | C_comp { cfields = None} -> Domain.empty
        | C_comp { cfields = Some fds } ->
          List.fold_left
            (fun dom fd ->
               let obj = Ctypes.object_of fd.ftype in
               let loc = field loc fd in
               Domain.union dom (footprint ~value obj loc)
            ) Domain.empty fds
        | C_array { arr_element = elt } ->
          let obj = object_of elt in
          footprint ~value obj (shift loc obj e_zero)
        | C_int _ | C_float _ | C_pointer _ ->
          match R.kind r with
          | Garbled ->
            Sigma.mdomain @@ mfootprint ~value obj l
          | Single p ->
            let mu = if value then RChunk.Value p else ValInit in
            Sigma.rdomain @@ RHeap.Set.singleton { mu ; region = r }
          | Many p ->
            let mu = if value then RChunk.Array p else ArrInit in
            Sigma.rdomain @@ RHeap.Set.singleton { mu ; region = r }

    let value_footprint = footprint ~value:true
    let init_footprint = footprint ~value:false

  end

  type loc = Loader.loc
  type segment = loc rloc

  open Loader
  module LOADER = MemLoader.Make(Loader)

  let load = LOADER.load
  let load_init = LOADER.load_init
  let stored = LOADER.stored
  let stored_init = LOADER.stored_init
  let copied = LOADER.copied
  let copied_init = LOADER.copied_init
  let initialized = LOADER.initialized
  let domain = LOADER.domain
  let assigned = LOADER.assigned

  (* {2 Reversing the Model} *)

  type state = M.state

  let state sigma = M.state (fst sigma)

  let lookup s e = M.lookup s e

  let updates = M.updates

  let apply = M.apply

  let iter = M.iter

  let pretty fmt (l: loc) =
    match l with
    | Null -> M.pretty fmt M.null
    | Raw l -> M.pretty fmt l
    | Loc (l,r) -> Format.fprintf fmt "%a@%a" M.pretty l R.Type.pretty r

  (* {2 Memory Model API} *)

  let vars l = M.vars @@ loc l
  let occurs x l = M.occurs x @@ loc l
  let null = Null

  let literal ~eid:eid str = make (M.literal ~eid str) (R.literal ~eid str)

  let cvar v = make (M.cvar v) (R.cvar v)
  let field = field
  let shift = shift

  let pointer_loc t = Raw (M.pointer_loc t)
  let pointer_val l = M.pointer_val @@ loc l
  let base_addr l = Raw (M.base_addr @@ loc l)
  let base_offset l = M.base_offset @@ loc l
  let block_length sigma obj l = M.block_length (fst sigma) obj @@ loc l
  let is_null = function Null -> p_true | Raw l | Loc(l,_) -> M.is_null l
  let loc_of_int obj t = Raw (M.loc_of_int obj t)
  let int_of_loc iota l = M.int_of_loc iota @@ loc l

  let cast conv l =
    let l0 = loc l in
    let r0 = reg l in
    make (M.cast conv l0) r0

  let loc_eq  a b = M.loc_eq  (loc a) (loc b)
  let loc_lt  a b = M.loc_lt  (loc a) (loc b)
  let loc_neq a b = M.loc_neq (loc a) (loc b)
  let loc_leq a b = M.loc_leq (loc a) (loc b)
  let loc_diff obj a b = M.loc_diff obj (loc a) (loc b)

  let rloc = function
    | Rloc(obj, l) -> Rloc (obj, loc l)
    | Rrange(l, obj, inf, sup) -> Rrange(loc l, obj, inf, sup)

  let rloc_region = function Rloc(_,l) | Rrange(l,_,_,_) -> reg l

  let valid sigma acs r = M.valid (fst sigma) acs @@ rloc r
  let invalid sigma r = M.invalid (fst sigma) (rloc r)

  let included (a : segment) (b : segment) =
    match rloc_region a, rloc_region b with
    | Some ra, Some rb when R.separated ra rb -> p_false
    | _ -> M.included (rloc a) (rloc b)

  let separated (a : segment) (b : segment) =
    match rloc_region a, rloc_region b with
    | Some ra, Some rb when R.separated ra rb -> p_true
    | _ -> M.separated (rloc a) (rloc b)

  let alloc sigma vars =
    if vars = [] then sigma else
      let m,r = sigma in M.alloc m vars, r

  let scope seq scope vars = M.scope (mseq seq) scope vars

  let global sigma p = M.global (fst sigma) p

  let frame sigma =
    let pool = ref @@ M.frame (fst sigma) in
    let assume p = pool := p :: !pool in
    RSigma.iter
      (fun c m ->
         let open RChunk in
         match c.mu with
         | ValInit -> ()
         | ArrInit -> assume @@ MemMemory.cinits (e_var m)
         | Value Ptr -> assume @@ global sigma (e_var m)
         | Array Ptr -> assume @@ MemMemory.framed (e_var m)
         | Value (Int _ | Float _) | Array (Int _ | Float _) -> ()
      ) (snd sigma) ;
    !pool

  let is_well_formed sigma =
    let pool = ref @@ [M.is_well_formed (fst sigma)] in
    let assume p = pool := p :: !pool in
    RSigma.iter
      (fun c m ->
         let open RChunk in
         match c.mu with
         | ValInit | ArrInit -> ()
         | Value (Int iota) -> assume @@ Cint.range iota (e_var m)
         | Array (Int iota) ->
           let a = Lang.freshvar ~basename:"p" @@ Lang.t_addr () in
           let b = e_get (e_var m) (e_var a) in
           assume @@ p_forall [a] (Cint.range iota b)
         | Value (Float _ | Ptr) | Array (Float _ | Ptr) -> ()
      ) (snd sigma) ;
    p_conj !pool

end
