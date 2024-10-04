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
open Lang
open Lang.F
open Sigs
open MemMemory

type primitive = Int of c_int | Float of c_float | Ptr
type kind = Single of primitive | Many of primitive | Garbled

let pp_prim fmt = function
  | Int i -> Ctypes.pp_int fmt i
  | Float f -> Ctypes.pp_float fmt f
  | Ptr -> Format.pp_print_string fmt "void*"
let pp_kind fmt = function
  | Single p -> pp_prim fmt p
  | Many p -> Format.fprintf fmt "[%a]" pp_prim p
  | Garbled -> Format.pp_print_string fmt "[bytes]"

let tau_of_primitive = function
  | Int _ -> Qed.Logic.Int
  | Float c_float -> Cfloat.tau_of_float c_float
  | Ptr -> MemAddr.t_addr

(* -------------------------------------------------------------------------- *)
(* --- Region Analysis Proxy                                              --- *)
(* -------------------------------------------------------------------------- *)

module type RegionProxy =
sig
  type region
  val null : unit -> region

  val hash : region -> int
  val equal : region -> region -> bool
  val compare : region -> region -> int
  val pretty : Format.formatter -> region -> unit

  val kind : region -> kind

  val tau_of_region : region -> tau
  val points_to : region -> region option

  val separated : region -> region -> bool
  val included : region -> region -> bool

  val cvar : varinfo -> region option
  val field : region -> fieldinfo -> region option
  val shift : region -> c_object -> term -> region option
  val base_addr : region -> region

  val literal : eid:int -> Cstring.cst -> region option
  val pointer_loc : unit -> region option
  val loc_of_int : unit -> region option

  val id_of_region : region -> int
  val region_of_id : int -> region option

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

module Make (R:RegionProxy) (M:ModelWithLoader) : Sigs.Model =
struct

  type region = R.region
  let datatype = "MemRegion.Make"
  (* For projectification. Must be unique among models. *)

  let configure = M.configure
  let configure_ia = M.configure_ia
  let hypotheses = M.hypotheses

  module BChunk = struct

    (* Do not warn on unused constructors, even if they are not used yet. *)
    [@@@ warning "-37" ]

    type t =
      | CVal of R.region
      | CInit of R.region
      | CGhost of R.region

    let self = "MemRegion.Make.RegionChunk"

    let hash = function
      | CVal r -> 0x02 * R.hash r
      | CInit r -> 0x100 * R.hash r
      | CGhost r -> 0x10000 * R.hash r

    let equal c1 c2 = match c1, c2 with
      | CVal r1, CVal r2 | CInit r1, CInit r2 | CGhost r1, CGhost r2 -> R.equal r1 r2
      | _ -> false

    let compare c1 c2 = hash c1 - hash c2

    let pretty fmt = function
      | CVal   _ -> Format.fprintf fmt "Value"
      | CInit  _ -> Format.fprintf fmt "Init"
      | CGhost _ -> Format.fprintf fmt "Ghost"

    let tau_of_chunk = function
      | CVal r | CGhost r ->
        begin match R.kind r with
          | Single p -> tau_of_primitive p
          | Many   p -> Qed.Logic.Array (MemAddr.t_addr, tau_of_primitive p)
          | Garbled  -> assert false
        end
      | CInit  r ->
        begin match R.kind r with
          | Single _ -> t_bool
          | Many   _ -> t_init
          | Garbled -> assert false
        end

    let basename_of_chunk = function
      | CGhost _ -> "GhostChunk"
      | CVal   _ -> "ValueChunk"
      | CInit  _ -> "InitChunk"

    let is_framed _ = false

  end

  module B = BChunk

  module BHeap = Qed.Collection.Make(B)

  module BSigma = Sigma.Make(BChunk)(BHeap)

  module Chunk =
  struct
    type t =
      | CModel of M.chunk
      | CRegion of BChunk.t

    let self = "MemRegion.Make.Chunk"

    let hash = function
      | CModel c -> M.Chunk.hash c
      | CRegion c -> 0x1000 * (B.hash c)

    let equal ca cb = match ca, cb with
      | CModel  c1, CModel  c2 -> M.Chunk.equal c1 c2
      | CRegion c1, CRegion c2 -> B.equal       c1 c2
      | CModel _, CRegion _ | CRegion _, CModel _ -> false

    let compare c1 c2 = (hash c1) - (hash c2)

    let pretty fmt = function
      | CModel  c -> Format.fprintf fmt "CModel.%a" M.Chunk.pretty c
      | CRegion c -> Format.fprintf fmt "CRegion.%a" B.pretty c

    let tau_of_chunk = function
      | CModel c -> M.Chunk.tau_of_chunk c
      | CRegion c -> B.tau_of_chunk c

    let basename_of_chunk = function
      | CModel  _ -> "Model"
      | CRegion _ -> "Region"
    (* Used when generating fresh variables for a chunk. *)

    let is_framed = function
      | CModel c -> M.Chunk.is_framed c
      | CRegion _ -> false

  end

  module Heap = Qed.Collection.Make(Chunk)

  module Tuple = struct
    type ('a, 'b) tuple = {
      model  : 'a ;
      region : 'b ;
    }

    let create f1 f2 input = {
      model  = f1 input ;
      region = f2 input ;
    }

    let iter f1 f2 tuple =
      f1 tuple.model  ;
      f2 tuple.region ;
      ()

    let iter2 f1 f2 t1 t2 =
      f1 t1.model  t2.model  ;
      f2 t1.region t2.region ;
      ()

    let choose_apply f1 f2 tuple = function
      | Chunk.CModel  c -> f1 tuple.model  c
      | Chunk.CRegion c -> f2 tuple.region c

    let choose_map f1 f2 tuple = function
      | Chunk.CModel  c -> { tuple with model  = f1 tuple.model  c }
      | Chunk.CRegion c -> { tuple with region = f2 tuple.region c }

    let map f1 f2 tuple = {
      model  = f1 tuple.model  ;
      region = f2 tuple.region ;
    }

    let map2 f1 f2 t1 t2 = {
      model = f1 t1.model t2.model ;
      region = f2 t1.region t2.region ;
    }

    let sequence_map f1 f2 seq = {
      model  = f1 { pre = seq.pre.model  ; post = seq.post.model  } ;
      region = f2 { pre = seq.pre.region ; post = seq.post.region } ;
    }
  end

  type sigma = (M.sigma, BSigma.t) Tuple.tuple

  module Sigma = (* Sigma.Make(Chunk)(Heap) *) struct

    open Tuple
    type t = sigma
    type chunk = Chunk.t

    open Chunk

    type domain = Heap.set

    type dom = (M.Sigma.domain, BSigma.domain) Tuple.tuple

    (* local *)
    let chunk_split_list l =
      let rec aux acc1 acc2 = function
        | [] -> { model = List.rev acc1 ; region = List.rev acc2 }
        | CModel  c :: rest -> aux (c::acc1) acc2 rest
        | CRegion c :: rest -> aux acc1 (c::acc2) rest
      in aux [] [] l

    let of_domain (domain:domain) : dom =
      Tuple.map
        M.Sigma.Chunk.Set.of_list
        BSigma.Chunk.Set.of_list
      @@ chunk_split_list
      @@ Heap.Set.elements domain

    let to_domain (dom:dom) : domain =
      let cmodel = M.Heap.Set.elements dom.model in
      let cRegion = BSigma.Chunk.Set.elements dom.region in
      let model = Heap.Set.of_list (List.map (fun c -> CModel  c) cmodel) in
      let region = Heap.Set.of_list (List.map (fun c -> CRegion c) cRegion) in
      Heap.Set.union model region

    module Chunk = Heap


    let create = Tuple.create M.Sigma.create BSigma.create

    let pretty fmt sigma =
      Format.fprintf fmt "@[{@[%a@];@[%a@]}@]"
        M.Sigma.pretty sigma.model
        BSigma.pretty sigma.region

    let empty : domain = Heap.Set.empty

    let mem = Tuple.choose_apply M.Sigma.mem BSigma.mem

    let get = Tuple.choose_apply M.Sigma.get BSigma.get

    let writes sigma = to_domain @@ Tuple.sequence_map M.Sigma.writes BSigma.writes sigma

    let value = Tuple.choose_apply M.Sigma.value BSigma.value

    let copy = Tuple.map M.Sigma.copy BSigma.copy

    let join sigma1 sigma2 =
      let r = Tuple.map2 M.Sigma.join BSigma.join sigma1 sigma2 in
      Passive.union r.model r.region

    let assigned ~pre:sigma1 ~post:sigma2 domain =
      let dom = of_domain domain in
      Bag.concat (M.Sigma.assigned ~pre:sigma1.model ~post:sigma2.model dom.model)
      @@ BSigma.assigned ~pre:sigma1.region ~post:sigma2.region dom.region

    let choose = Tuple.map2 M.Sigma.choose BSigma.choose

    let merge s1 s2 =
      let (sm, pm1, pm2) = M.Sigma.merge s1.model s2.model in
      let (sb, pb1, pb2) = BSigma.merge s1.region s2.region in
      let s = { model = sm ; region = sb } in
      let p1 = Passive.union pm1 pb1 in
      let p2 = Passive.union pm2 pb2 in
      (s,p1,p2)

    let merge_list ls = (* TOCHECK *)
      let f (s1,lp) s2 =
        let (s,p1,p2) = merge s1 s2 in
        (s, p1::p2::lp)
      in
      match ls with
      | [] -> (create (), [])
      | [ s ] -> (s, [ Passive.empty ])
      | _ -> List.fold_left f (create (), []) ls

    let iter f =
      Tuple.iter
        (M.Sigma.iter (fun c -> f (CModel c)))
        (BSigma.iter (fun c -> f (CRegion c)))

    let iter2 f =
      Tuple.iter2
        (M.Sigma.iter2 (fun c -> f (CModel c)))
        (BSigma.iter2 (fun c -> f (CRegion c)))

    let havoc_chunk = Tuple.choose_map M.Sigma.havoc_chunk BSigma.havoc_chunk

    let havoc sigma domain =
      let dom = of_domain domain in
      Tuple.map2 M.Sigma.havoc BSigma.havoc sigma dom

    let havoc_any ~call:call =
      Tuple.map (M.Sigma.havoc_any ~call) (BSigma.havoc_any ~call)

    let remove_chunks sigma domain =
      let dom = of_domain domain in
      Tuple.map2 M.Sigma.remove_chunks BSigma.remove_chunks sigma dom

    let dom = Tuple.map M.Sigma.domain BSigma.domain

    let domain sigma =
      let dom = dom sigma in
      Chunk.Set.of_list
      @@ List.append
        (List.map (fun l -> CModel l) (M.Heap.Set.elements dom.model))
        (List.map (fun c -> CRegion c) (BHeap.Set.elements dom.region))

    let union = Chunk.Set.union

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
      | Raw of { repr : M.loc }
      | Loc   of { repr : M.loc ; region : region }


    (* ---------------------------------------------------------------------- *)
    (* --- Utilities on locations                                         --- *)
    (* ---------------------------------------------------------------------- *)

    let last sigma ty = function
      | Null ->
        Warning.emit ~severe:false ~source:"MemRegion.Region.last"
          ~effect:"Loc is NULL" "loc=NULL" ;
        M.pointer_val M.null
      | Raw { repr } ->
        Warning.emit ~severe:false ~source:"MemRegion.Region.last"
          ~effect:"Loc is Raw" "loc=%a" M.pretty repr ;
        M.last sigma.Tuple.model ty repr
      | Loc { repr } -> M.last sigma.Tuple.model ty repr

    (* Conversion among loc, t_pointer terms and t_addr terms *)
    let to_addr = function
      | Null -> M.pointer_val M.null
      | Raw { repr } -> M.pointer_val repr
      | Loc { repr } -> M.pointer_val repr

    let to_region_pointer = function
      | Null -> (0, M.pointer_val M.null)
      | Raw { repr } -> (0, M.pointer_val repr)
      | Loc { repr ; region } -> (R.id_of_region region, M.pointer_val repr)

    let of_region_pointer id _ty term =
      if id == 0 then
        if QED.equal term (M.pointer_val M.null) then Null else
          let _ =
            Warning.emit ~severe:false ~source:"MemRegion.Region.of_region_pointer"
              ~effect:"No region has been found" "Region_id is zero for loc=%a"
              QED.pretty term
          in Raw { repr = M.pointer_loc term }
      else match R.region_of_id id with
        | None ->
          let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.of_region_pointer"
              ~effect:"No region has been found" "Region_id=%d for term=%a" id
              QED.pretty term
          in Raw { repr = M.pointer_loc term }
        | Some region -> Loc { repr = M.pointer_loc term ; region }

    (* Basic operations *)
    let sizeof ty = M.sizeof ty

    let field loc field : loc = (* TODO: reconstruction *) match loc with
      | Null -> Null
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.field"
            ~effect:"Loc is Raw" "(%a).(%a)"
            M.pretty repr Printer.pp_field field
        in Raw { repr = M.field repr field }
      | Loc { repr ; region } ->
        match R.field region field with
        | None ->
          let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.field"
              ~effect:"No region for field" "(%a in %a).(%a)"
              M.pretty repr R.pretty region Printer.pp_field field
          in Raw { repr = M.field repr field }
        | Some region -> Loc { repr = M.field repr field ; region }

    let shift loc ty offset = match loc with
      | Null -> Null
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.shift"
            ~effect:"Loc is Raw" "No region for (%a).[%a : %a]"
            M.pretty repr QED.pretty offset Ctypes.pp_object ty
        in Raw { repr = M.shift repr ty offset }
      | Loc { repr ; region } ->
        match R.shift region ty offset with
        | None ->
          let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.field"
              ~effect:"No region for shift" "No region for (%a in %a).[%a : %a]"
              M.pretty repr R.pretty region QED.pretty offset Ctypes.pp_object ty
          in Raw { repr = M.shift repr ty offset }
        | Some region ->
          Loc { repr = M.shift repr ty offset ; region }

    let frames_repr_region ty mloc r c =
      match R.kind r with
      | Single Ptr | Many Ptr ->
        let offset = M.sizeof ty in
        let sizeof = F.e_one in
        let tau = Chunk.tau_of_chunk c in
        let basename = Chunk.basename_of_chunk c in
        MemMemory.frames ~addr:(M.pointer_val mloc) ~offset ~sizeof ~basename tau
      | _ -> []

    let frames ty loc chunk =
      match loc with
      | Null -> []
      | Raw { repr } -> begin match chunk with
          | Chunk.CModel c ->
            let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.frames"
                ~effect:"Loc is Raw" "Frames %a" M.pretty repr
            in M.frames ty repr c
          | Chunk.CRegion (B.CVal r | B.CInit r | B.CGhost r) ->
            frames_repr_region ty repr r chunk
        end
      | Loc { repr ; region } -> frames_repr_region ty repr region chunk
          (*
        begin match R.kind r with
        | Single Ptr | Many Ptr -> [MemMemory.framed (Sigma.value chunk)]
        | _ -> []
        end *)
      (*
      si chunk = CVal r et R.tau_of_region == ptr then the predicate MemMemory.framed (Sigma.value chunk)
      si chunk = CInit r then MemMemory.cinits (Sigma.value chunk)
      *)

    let havoc ty loc ~length chunk ~fresh ~current = match loc with
      | Null ->
        F.e_fun f_havoc [fresh;current;M.pointer_val M.null;length]
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.havoc"
            ~effect:"Loc is Raw" "havoc of Raw=%a"
            M.pretty repr
        in F.e_fun f_havoc [fresh;current;M.pointer_val repr;length]
      | Loc { repr } ->
        (* TO CHECK *) assert (QED.equal length F.e_one) ;
        match chunk with
        | Chunk.CModel c -> M.havoc ty repr ~length c ~fresh ~current
        | Chunk.CRegion _ ->
          F.e_fun f_havoc [fresh;current;M.pointer_val repr;length]


    let eqmem_forall ty loc chunk m1 m2 = match loc, chunk with
      | Null, Chunk.CModel  c -> M.eqmem_forall ty M.null c m1 m2
      | Null, Chunk.CRegion _ ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.eqmem_forall"
            ~effect:"Loc is NULL" "Los is Null in eqmem_forall"
        in [], p_true, p_true
      | (Raw { repr } | Loc { repr }), Chunk.CModel  c ->
        M.eqmem_forall ty repr c m1 m2
      | (Raw { repr } | Loc { repr }), Chunk.CRegion _ ->
        let xp = Lang.freshvar ~basename:"b" MemAddr.t_addr in
        let p = F.e_var xp in
        let n = M.sizeof ty in
        let separated = F.p_call MemAddr.p_separated [p;e_one;M.pointer_val repr;n] in
        let equal = p_equal (e_get m1 p) (e_get m2 p) in
        [xp],separated,equal

    (* ---------------------------------------------------------------------- *)
    (* --- Load                                                           --- *)
    (* ---------------------------------------------------------------------- *)

    let load_int sigma (c_int:c_int) loc : term = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.load_int"
            ~effect:"Loc is Null" "Attempt to load_int inside Null"
        in M.load_int sigma.Tuple.model c_int M.null
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.load_int"
            ~effect:"Loc is Raw" "load_int(Raw %a)" M.pretty repr
        in M.load_int sigma.Tuple.model c_int repr
      | Loc { repr ; region } ->
        let c = Chunk.CRegion (B.CVal region) in
        match R.kind region with
        | Many (Int c_int') ->
          if compare_c_int c_int c_int' = 0
          then F.e_get (Sigma.value sigma c) @@ M.pointer_val repr
          else
            let _ =
              Warning.emit ~severe:false ~source:"MemRegion.Region.load_int"
                ~effect:"C_int type is not the same in chunk and in argument"
                "%a!=%a" Ctypes.pp_int c_int Ctypes.pp_int c_int'
            in F.e_get (Sigma.value sigma c)
            @@ M.pointer_val repr
        | Single (Int c_int') ->
          if compare_c_int c_int c_int' = 0
          then Sigma.value sigma c
          else
            let _ =
              Warning.emit ~severe:false ~source:"MemRegion.Region.load_int"
                ~effect:"C_int type is not the same in chunk and in argument"
                "%a!=%a" Ctypes.pp_int c_int Ctypes.pp_int c_int'
            in Sigma.value sigma c
        | Garbled -> M.load_int sigma.model c_int repr
        | k ->
          let _ =
            Warning.emit ~severe:false ~source:"MemRegion.Region.load_int"
              ~effect:"Region's kind is not Int" "%a : %a != %a"
              R.pretty region pp_kind k Ctypes.pp_int c_int
          in assert false

    let load_float sigma (c_float:c_float) loc : term = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.load_float"
            ~effect:"Loc is Null" "Attempt to load_float inside Null"
        in M.load_float sigma.Tuple.model c_float M.null
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.load_float"
            ~effect:"Loc is Raw" "load_float(Raw %a)" M.pretty repr
        in M.load_float sigma.Tuple.model c_float repr
      | Loc { repr ; region } ->
        let c = Chunk.CRegion (B.CVal region) in
        match R.kind region with
        | Many (Float c_float') ->
          if compare_c_float c_float c_float' = 0
          then F.e_get (Sigma.value sigma c) @@ M.pointer_val repr
          else
            let _ = Warning.emit ~severe:false
                ~source:"MemRegion.Region.load_float"
                ~effect:"Type is not the same in chunk and in argument" "%a!=%a"
                Ctypes.pp_float c_float Ctypes.pp_float c_float'
            in F.e_get (Sigma.value sigma c) @@ M.pointer_val repr
        | Single (Float c_float') ->
          if compare_c_float c_float c_float' = 0
          then Sigma.value sigma c
          else
            let _ = Warning.emit ~severe:false
                ~source:"MemRegion.Region.load_float"
                ~effect:"Type is not the same in chunk and in argument" "%a!=%a"
                Ctypes.pp_float c_float Ctypes.pp_float c_float'
            in Sigma.value sigma c
        | Garbled -> M.load_float sigma.model c_float repr
        | k ->
          let _ =
            Warning.emit ~severe:false ~source:"MemRegion.Region.load_float"
              ~effect:"Region's kind is not Float" "%a : %a != %a"
              R.pretty region pp_kind k Ctypes.pp_float c_float
          in assert false

    let load_pointer sigma ty loc : loc = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.load_float"
            ~effect:"Loc is Null" "Attempt to load_float inside Null"
        in let mloc = M.load_pointer sigma.Tuple.model ty M.null in
        if QED.equal (M.pointer_val mloc) (M.pointer_val M.null)
        then Null else Raw { repr = mloc }
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.load_pointer"
            ~effect:"Loc is Raw" "load_pointer(Raw %a : *%a)"
            M.pretty repr Printer.pp_typ ty
        in Raw { repr = M.load_pointer sigma.Tuple.model ty repr }
      | Loc { repr ; region } ->
        let c = Chunk.CRegion (B.CVal region) in
        match R.points_to region with
        | None ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.load_pointer"
              ~effect:"No region pointed" "No region for *(%a in %a)"
              M.pretty repr R.pretty region
          in Raw { repr = M.load_pointer sigma.Tuple.model ty repr }
        | Some r ->
          let repr = match R.kind region with
            | Many (Ptr) ->
              M.pointer_loc
              @@ F.e_get (Sigma.value sigma c) @@ M.pointer_val repr
            | Single (Ptr) -> M.pointer_loc @@ Sigma.value sigma c
            | Garbled -> M.load_pointer sigma.Tuple.model ty repr
            | k ->
              let _ = Warning.emit ~severe:false
                  ~source:"MemRegion.Region.load_pointer"
                  ~effect:"Kind of region is not a pointer"
                  "Region %a : %a != %a"
                  R.pretty region pp_kind k Printer.pp_typ ty
              in assert false
          in Loc { repr ; region = r }

    (* ---------------------------------------------------------------------- *)
    (* --- Store                                                          --- *)
    (* ---------------------------------------------------------------------- *)

    let store_int sigma c_int loc v : Chunk.t * term = match loc with
      | Null ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.store_int"
            ~effect:"Loc is Null" "Attempt to store_int inside Null"
        in let c, t = M.store_int sigma.Tuple.model c_int M.null v in
        Chunk.CModel c, t
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false ~source:"MemRegion.Region.store_int"
            ~effect:"Loc is Raw" "store_int(Raw %a)" M.pretty repr
        in let c, t = M.store_int sigma.Tuple.model c_int repr v in
        Chunk.CModel c, t
      | Loc { repr ; region } ->
        let c = Chunk.CRegion (B.CVal region) in
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
          (Chunk.CModel c', v)
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
        Chunk.CModel c, t
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.store_float"
            ~effect:"Loc is Raw" "store_float(Raw %a)" M.pretty repr
        in let c, t = M.store_float sigma.Tuple.model c_float repr v in
        Chunk.CModel c, t
      | Loc { repr ; region } ->
        let c = Chunk.CRegion (B.CVal region) in
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
          (Chunk.CModel c, t)
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
        Chunk.CModel c, t
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.store_pointer"
            ~effect:"Loc is Raw" "store_pointer(Raw %a : *%a)"
            M.pretty repr Printer.pp_typ ty
        in let c, t = M.store_pointer sigma.Tuple.model ty repr v in
        Chunk.CModel c, t
      | Loc { repr ; region } ->
        let c = Chunk.CRegion (B.CVal region) in
        match R.kind region with
        | Many (Ptr) ->
          c, F.e_set (Sigma.value sigma c) (M.pointer_val repr) v
        | Single (Ptr) -> c,v
        | Garbled ->
          let (c, repr) = M.store_pointer sigma.Tuple.model ty repr v in
          (Chunk.CModel c, repr)
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
        (Chunk.CModel c, t)
      | Raw { repr } ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.set_init_atom"
            ~effect:"Loc is Raw" "set_init_atom(Raw %a <- %a)"
            M.pretty repr QED.pretty v
        in let (c, t) = M.set_init_atom sigma.Tuple.model ty repr v in
        (Chunk.CModel c, t)
      | Loc { repr ; region }->
        match R.kind region with
        | Garbled ->
          let (c, t) = M.set_init_atom sigma.Tuple.model ty repr v in
          (Chunk.CModel c, t)
        | Single _-> Chunk.CRegion (B.CInit region), v
        | Many _ ->
          let c = Chunk.CRegion (B.CInit region) in
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
        let c = Chunk.CRegion (B.CInit region) in
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
          let c = Chunk.CRegion (B.CInit region) in
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
      | Null, Chunk.CModel c ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.set_init"
            ~effect:"Loc is Null" "set_init(Null)"
        in M.set_init ty M.null ~length c ~current
      | Null, Chunk.CRegion _ ->
        let _ = Warning.emit ~severe:false
            ~source:"MemRegion.Region.set_init"
            ~effect:"Loc is Null" "set_init(Null) and Chunk is Region"
        in assert false
      | Raw { repr }, Chunk.CModel c ->
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
      | Loc { repr }, Chunk.CModel c -> M.set_init ty repr ~length c ~current
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
        Sigma.to_domain Tuple.{ model ; region = BSigma.empty }
      | Loc { repr ; region } ->
        match R.kind region, ty with
        | Garbled, (C_int _ | C_float _ | C_pointer _) ->
          let model = M.value_footprint ty repr in
          Sigma.to_domain Tuple.{ model ; region = BSigma.empty }
        | (Many (Int   _) | Single (Int   _)), C_int _
        | (Many (Float _) | Single (Float _)), C_float _
        | (Many (Ptr    ) | Single (Ptr    )), C_pointer _->
          Heap.Set.singleton (Chunk.CRegion (B.CVal region))
        | (Many _ | Single _) as k, (C_int _ | C_float _ | C_pointer _) ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.value_footprint"
              ~effect:"Type is not the same in chunk and in argument"
              "value_footprint(%a : %a in %a : %a)"
              M.pretty repr Ctypes.pp_object ty R.pretty region pp_kind k
          in Heap.Set.singleton @@ Chunk.CRegion (B.CVal region)
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
        Sigma.to_domain Tuple.{ model ; region = BSigma.empty }
      | Loc { repr ; region } ->
        match R.kind region, ty with
        | Garbled, (C_int _ | C_float _ | C_pointer _) ->
          let model =  M.init_footprint ty repr in
          Sigma.to_domain Tuple.{ model ; region = BSigma.empty }
        | (Many (Int   _) | Single (Int   _)), C_int _
        | (Many (Float _) | Single (Float _)), C_float _
        | (Many (Ptr    ) | Single (Ptr    )), C_pointer _->
          Heap.Set.singleton @@ Chunk.CRegion (B.CInit region)
        | (Many _ | Single _) as k, (C_int _ | C_float _ | C_pointer _) ->
          let _ = Warning.emit ~severe:false
              ~source:"MemRegion.Region.init_footprint"
              ~effect:"Type is not the same in chunk and in argument"
              "init_footprint(%a : %a in %a : %a)"
              M.pretty repr Ctypes.pp_object ty R.pretty region pp_kind k
          in Heap.Set.singleton @@ Chunk.CRegion (B.CInit region)
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
              @@ Sigma.value seq.post @@ Chunk.CRegion (B.CInit region)) ::
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
    BSigma.Chunk.Set.fold
      (fun c l -> region_frame sigma c :: l)
      (BSigma.domain sigma.region)
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
    | Chunk.CModel _ | Chunk.CRegion (B.CInit _)
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
