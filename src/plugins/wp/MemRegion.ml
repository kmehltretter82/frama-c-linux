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
open Memory
open Sigma
open MemMemory

type prim = Int of c_int | Float of c_float | Ptr
type kind = Single of prim | Many of prim | Garbled

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
  val id : region -> int
  val of_id : int -> region option
  val pretty : Format.formatter -> region -> unit
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
  include Memory.Model
  val sizeof : c_object -> term

  val last : sigma -> c_object -> loc -> term
  val frames : c_object -> loc -> chunk -> frame list

  val memcpy : c_object -> mtgt:term -> msrc:term -> ltgt:loc -> lsrc:loc ->
    length:term -> Chunk.t -> term

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

module Make (R:RegionProxy) (M:ModelWithLoader) (*: Memory.Model*) =
struct

  type region = R.region
  let datatype = "MemRegion.Make"
  (* For projectification. Must be unique among models. *)

  let configure = M.configure
  let configure_ia = M.configure_ia
  let hypotheses = M.hypotheses

  module Chunk =
  struct
    let self = "MemRegion.Chunk"

    type data = Value of prim | Array of prim | ValInit | ArrInit
    type t = { data : data ; region : R.region }

    let pp_data fmt = function
      | Value p -> Format.fprintf fmt "µ%a" pp_prim p
      | Array p -> Format.fprintf fmt "µ%a[]" pp_prim p
      | ValInit -> Format.pp_print_string fmt "µinit"
      | ArrInit -> Format.pp_print_string fmt "µinit[]"

    let hash { data ; region } = Hashtbl.hash (data, R.id region)
    let equal a b = Stdlib.(=) a.data b.data && R.id a.region = R.id b.region
    let compare a b =
      let cmp = Stdlib.compare a.data b.data in
      if cmp <> 0 then cmp else Int.compare (R.id a.region) (R.id b.region)

    let pretty fmt { data ; region } =
      Format.fprintf fmt "%a@%03d" pp_data data (R.id region)

    let tau_of_chunk { data } =
      match data with
      | Value p -> tau_of_prim p
      | ValInit -> Qed.Logic.Bool
      | Array p -> Qed.Logic.Array(MemAddr.t_addr,tau_of_prim p)
      | ArrInit -> Qed.Logic.Array(MemAddr.t_addr,Qed.Logic.Bool)

    let basename_of_chunk c =
      match c.data with
      | ValInit -> "Vinit"
      | ArrInit -> "Minit"
      | Array p -> Format.asprintf "M%a" pp_prim p
      | Value p ->
        match R.name c.region with
        | Some a -> a
        | None -> Format.asprintf "V%a" pp_prim p

    let is_init c =
      match c.data with
      | ValInit | ArrInit -> true
      | Array _ | Value _ -> false

    let is_primary c =
      match c.data with
      | Value _ -> true
      | ValInit | ArrInit | Array _ -> false

    let is_framed _ = false

  end

  module State = Sigma.Make(Chunk)

  (* -------------------------------------------------------------------------- *)
  (* --- Region Loader                                                         --- *)
  (* -------------------------------------------------------------------------- *)

  module Loader =
  struct
    let name = "MemRegion.Loader"

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

    let last sigma ty l = M.last sigma ty (loc l)

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
        let tau = Sigma.Chunk.tau_of_chunk c in
        let basename = Sigma.Chunk.basename_of_chunk c in
        MemMemory.frames ~addr:(to_addr l) ~offset ~sizeof ~basename tau
      | _ -> []

    let memcpy ty ~mtgt ~msrc ~ltgt ~lsrc ~length chunk =
      match Sigma.ckind chunk with
      | State.Mu { data } ->
        begin
          match data with
          | Value _ | ValInit -> msrc
          | Array _ | ArrInit ->
            e_fun f_memcpy [mtgt;msrc;to_addr ltgt;to_addr lsrc;length]
        end
      | _ ->
        M.memcpy ty ~mtgt ~msrc ~ltgt:(loc ltgt) ~lsrc:(loc lsrc) ~length chunk

    let eqmem_forall ty l chunk m1 m2 =
      match Sigma.ckind chunk with
      | State.Mu { data } ->
        begin
          match data with
          | Value _ | ValInit -> [], p_true, p_equal m1 m2
          | Array _ | ArrInit ->
            let xp = Lang.freshvar ~basename:"b" MemAddr.t_addr in
            let p = e_var xp in
            let n = M.sizeof ty in
            let separated =
              p_call MemAddr.p_separated [p;e_one;to_addr l;n] in
            let equal = p_equal (e_get m1 p) (e_get m2 p) in
            [xp],separated,equal
        end
      | _ -> M.eqmem_forall ty (loc l) chunk m1 m2

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

    let check_access action (p:prim) (q:prim) =
      if Stdlib.(<>) p q then
        Warning.error ~source:"MemRegion"
          "Inconsistent %s (%a <> %a)"
          action pp_prim p pp_prim q

    let load_int sigma iota loc : term =
      let l,r = localized "load int" loc in
      match R.kind r with
      | Garbled -> M.load_int sigma iota l
      | Single p ->
        check_access "load" p (Int iota) ;
        State.value sigma { data = Value p ; region = r }
      | Many p ->
        check_access "load" p (Int iota) ;
        e_get
          (State.value sigma { data = Array p ; region = r})
          (M.pointer_val l)

    let load_float sigma flt loc : term =
      let l,r = localized "load float" loc in
      match R.kind r with
      | Garbled -> M.load_float sigma flt l
      | Single p ->
        check_access "load" p (Float flt) ;
        State.value sigma { data = Value p ; region = r }
      | Many p ->
        check_access "load" p (Float flt) ;
        e_get
          (State.value sigma { data = Array p ; region = r})
          (M.pointer_val l)

    let load_pointer sigma ty loc : loc =
      let l,r = localized "load pointer" loc in
      match R.points_to r with
      | None ->
        Warning.error ~source:"MemRegion"
          "Attempt to load pointer without points-to@\n\
           (addr %a, region %a)"
          M.pretty l R.pretty r
      | Some _ as rp ->
        let loc =
          match R.kind r with
          | Garbled -> M.load_pointer sigma ty l
          | Single p ->
            check_access "load" p Ptr ;
            M.pointer_loc @@
            State.value sigma { data = Value p ; region = r }
          | Many p ->
            check_access "load" p Ptr ;
            M.pointer_loc @@
            e_get
              (State.value sigma { data = Array p ; region = r})
              (M.pointer_val l)
        in make loc rp

    (* ---------------------------------------------------------------------- *)
    (* --- Store                                                          --- *)
    (* ---------------------------------------------------------------------- *)

    let store_int sigma iota loc v : Sigma.chunk * term =
      let l,r = localized "store int" loc in
      match R.kind r with
      | Garbled ->
        M.store_int sigma iota l v
      | Single p ->
        check_access "store" p (Int iota) ;
        State.chunk { data = Value p ; region = r }, v
      | Many p ->
        check_access "store" p (Int iota) ;
        let rc = Chunk.{ data = Array p ; region = r } in
        State.chunk rc, e_set (State.value sigma rc) (M.pointer_val l) v

    let store_float sigma flt loc v : Sigma.chunk * term =
      let l,r = localized "store float" loc in
      match R.kind r with
      | Garbled ->
        M.store_float sigma flt l v
      | Single p ->
        check_access "store" p (Float flt) ;
        State.chunk { data = Value p ; region = r }, v
      | Many p ->
        check_access "store" p (Float flt) ;
        let rc = Chunk.{ data = Array p ; region = r } in
        State.chunk rc, e_set (State.value sigma rc) (M.pointer_val l) v

    let store_pointer sigma ty loc v : Sigma.chunk * term =
      let l,r = localized "store pointer" loc in
      match R.kind r with
      | Garbled ->
        M.store_pointer sigma ty l v
      | Single p ->
        check_access "store" p Ptr ;
        State.chunk { data = Value p ; region = r }, v
      | Many p ->
        check_access "store" p Ptr ;
        let rc = Chunk.{ data = Array p ; region = r } in
        State.chunk rc, e_set (State.value sigma rc) (M.pointer_val l) v

    (* ---------------------------------------------------------------------- *)
    (* --- Init                                                           --- *)
    (* ---------------------------------------------------------------------- *)

    let is_init_atom sigma ty loc : term =
      let l,r = localized "init atom" loc in
      match R.kind r with
      | Garbled -> M.is_init_atom sigma ty l
      | Single _-> State.value sigma { data = ValInit ; region = r }
      | Many _ ->
        e_get
          (State.value sigma { data = ArrInit ; region = r })
          (M.pointer_val l)

    let set_init_atom sigma ty loc v : Sigma.chunk * term =
      let l,r = localized "init atom" loc in
      match R.kind r with
      | Garbled ->
        M.set_init_atom sigma ty l v
      | Single _-> State.chunk { data = ValInit ; region = r }, v
      | Many _ ->
        let rc = Chunk.{ data = ArrInit ; region = r } in
        State.chunk rc, e_set (State.value sigma rc) (M.pointer_val l) v

    let is_init_range sigma ty loc length : pred =
      let l,r = localized "init atom" loc in
      match R.kind r with
      | Garbled -> M.is_init_range sigma ty l length
      | Single _ ->
        Lang.F.p_bool @@ State.value sigma { data = ValInit ; region = r }
      | Many _ ->
        let map = State.value sigma { data = ArrInit ; region = r } in
        let size = e_mul (M.sizeof ty) length in
        p_call p_is_init_r [map;M.pointer_val l;size]

    let set_init ty loc ~length chunk ~current : term =
      let l,r = localized "init atom" loc in
      match R.kind r with
      | Garbled -> M.set_init ty l ~length chunk ~current
      | Single _ -> e_true
      | Many _ ->
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
      | Null  -> mfootprint ~value obj M.null
      | Raw l -> mfootprint ~value obj l
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
          | Garbled -> mfootprint ~value obj l
          | Single p ->
            let data = if value then Chunk.Value p else ValInit in
            State.singleton { data ; region = r }
          | Many p ->
            let data = if value then Chunk.Array p else ArrInit in
            State.singleton { data ; region = r }

    let value_footprint = footprint ~value:true
    let init_footprint = footprint ~value:false

  end

  type loc = Loader.loc
  type segment = loc rloc

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

  let lookup = M.lookup (*TODO: lookups in MemRegion *)

  let updates = M.updates (*TODO: updates in MemRegion *)

  let pretty fmt (l: loc) =
    match l with
    | Null -> M.pretty fmt M.null
    | Raw l -> M.pretty fmt l
    | Loc (l,r) -> Format.fprintf fmt "%a@%a" M.pretty l R.pretty r

  (* {2 Memory Model API} *)

  let vars l = M.vars @@ Loader.loc l
  let occurs x l = M.occurs x @@ Loader.loc l
  let null = Loader.Null

  let literal ~eid:eid str =
    Loader.make (M.literal ~eid str) (R.literal ~eid str)

  let cvar v = Loader.make (M.cvar v) (R.cvar v)
  let field = Loader.field
  let shift = Loader.shift

  let pointer_loc t = Loader.Raw (M.pointer_loc t)
  let pointer_val l = M.pointer_val @@ Loader.loc l
  let base_addr l = Loader.Raw (M.base_addr @@ Loader.loc l)
  let base_offset l = M.base_offset @@ Loader.loc l
  let block_length sigma obj l = M.block_length sigma obj @@ Loader.loc l
  let is_null = function Loader.Null -> p_true | Raw l | Loc(l,_) -> M.is_null l
  let loc_of_int obj t = Loader.Raw (M.loc_of_int obj t)
  let int_of_loc iota l = M.int_of_loc iota @@ Loader.loc l

  let cast conv l =
    let l0 = Loader.loc l in
    let r0 = Loader.reg l in
    Loader.make (M.cast conv l0) r0

  let loc_eq  a b = M.loc_eq  (Loader.loc a) (Loader.loc b)
  let loc_lt  a b = M.loc_lt  (Loader.loc a) (Loader.loc b)
  let loc_neq a b = M.loc_neq (Loader.loc a) (Loader.loc b)
  let loc_leq a b = M.loc_leq (Loader.loc a) (Loader.loc b)
  let loc_diff obj a b = M.loc_diff obj (Loader.loc a) (Loader.loc b)

  let rloc = function
    | Rloc(obj, l) -> Rloc (obj, Loader.loc l)
    | Rrange(l, obj, inf, sup) -> Rrange(Loader.loc l, obj, inf, sup)

  let rloc_region = function Rloc(_,l) | Rrange(l,_,_,_) -> Loader.reg l

  let valid sigma acs r = M.valid sigma acs @@ rloc r
  let invalid sigma r = M.invalid sigma (rloc r)

  let included (a : segment) (b : segment) =
    match rloc_region a, rloc_region b with
    | Some ra, Some rb when R.separated ra rb -> p_false
    | _ -> M.included (rloc a) (rloc b)

  let separated (a : segment) (b : segment) =
    match rloc_region a, rloc_region b with
    | Some ra, Some rb when R.separated ra rb -> p_true
    | _ -> M.separated (rloc a) (rloc b)

  let alloc = M.alloc
  let scope = M.scope
  let global = M.global

  let frame sigma =
    let pool = ref @@ M.frame sigma in
    let assume p = pool := p :: !pool in
    Sigma.iter
      (fun c m ->
         match Sigma.ckind c with
         | State.Mu { data } ->
           begin
             match data with
             | ValInit -> ()
             | ArrInit -> assume @@ MemMemory.cinits (e_var m)
             | Value Ptr -> assume @@ global sigma (e_var m)
             | Array Ptr -> assume @@ MemMemory.framed (e_var m)
             | Value (Int _ | Float _) | Array (Int _ | Float _) -> ()
           end
         | _ -> ()
      ) sigma ;
    !pool

  let is_well_formed sigma =
    let pool = ref @@ [M.is_well_formed sigma] in
    let assume p = pool := p :: !pool in
    Sigma.iter
      (fun c m ->
         match Sigma.ckind c with
         | State.Mu { data } ->
           begin
             match data with
             | ValInit | ArrInit -> ()
             | Value (Int iota) -> assume @@ Cint.range iota (e_var m)
             | Array (Int iota) ->
               let a = Lang.freshvar ~basename:"p" @@ Lang.t_addr () in
               let b = e_get (e_var m) (e_var a) in
               assume @@ p_forall [a] (Cint.range iota b)
             | Value (Float _ | Ptr) | Array (Float _ | Ptr) -> ()
           end
         | _ -> ()
      ) sigma ;
    p_conj !pool

end
