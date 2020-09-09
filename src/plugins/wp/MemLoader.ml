(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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
(* --- Memory Model                                                       --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types
open Cil_datatype
open Definitions
open Ctypes
open Lang
open Lang.F
open Sigs

(* -------------------------------------------------------------------------- *)
(* --- Compound Loader                                                    --- *)
(* -------------------------------------------------------------------------- *)

let cluster () =
  Definitions.cluster ~id:"Compound" ~title:"Memory Compound Loader" ()

module type Model =
sig

  module Chunk : Chunk
  module Sigma : Sigma with type chunk = Chunk.t

  val name : string

  type loc
  val sizeof : c_object -> int
  val field : loc -> fieldinfo -> loc
  val shift : loc -> c_object -> term -> loc

  val to_addr : loc -> term
  val to_region_pointer : loc -> int * term
  val of_region_pointer : int -> c_object -> term -> loc

  val value_footprint: c_object -> loc -> Sigma.domain
  val init_footprint: c_object -> loc -> Sigma.domain

  val frames : c_object -> loc -> Chunk.t -> frame list

  val last : Sigma.t -> c_object -> loc -> term

  val havoc : c_object -> loc -> length:term ->
    Chunk.t -> fresh:term -> current:term -> term

  val eqmem : c_object -> loc -> Chunk.t -> term -> term -> pred

  val eqmem_forall :
    c_object -> loc -> Chunk.t -> term -> term -> var list * pred * pred

  val load_int : Sigma.t -> c_int -> loc -> term
  val load_float : Sigma.t -> c_float -> loc -> term
  val load_pointer : Sigma.t -> typ -> loc -> loc

  val store_int : Sigma.t -> c_int -> loc -> term -> Chunk.t * term
  val store_float : Sigma.t -> c_float -> loc -> term -> Chunk.t * term
  val store_pointer : Sigma.t -> typ -> loc -> term -> Chunk.t * term

  val is_init_atom : Sigma.t -> loc -> term
  val is_init_range : Sigma.t -> c_object -> loc -> term -> pred
  val set_init_atom : Sigma.t -> loc -> term -> Chunk.t * term
  val set_init : c_object -> loc -> length:term ->
    Chunk.t -> current:term -> term
  val monotonic_init : Sigma.t -> Sigma.t -> pred

end

module Make (M : Model) =
struct

  type chunk = M.Chunk.t

  module Chunk = M.Chunk
  module Sigma = M.Sigma
  module Domain = M.Sigma.Chunk.Set

  let signature ft =
    let s = Sigma.create () in
    let xs = ref [] in
    let cs = ref [] in
    Domain.iter
      (fun c ->
         cs := c :: !cs ;
         xs := (Sigma.get s c) :: !xs ;
      ) ft ;
    List.rev !xs , List.rev !cs , s

  let domain obj loc =
    M.Sigma.Chunk.Set.union
      (M.value_footprint obj loc)
      (M.init_footprint obj loc)

  let pp_rid fmt r = if r <> 0 then Format.fprintf fmt "_R%03d" r

  let loadrec = ref (fun _ _ _ -> assert false)

  (* -------------------------------------------------------------------------- *)
  (* --- Frame Lemmas for Compound Access                                   --- *)
  (* -------------------------------------------------------------------------- *)

  let memories sigma chunks = List.map (Sigma.value sigma) chunks
  let assigned sigma c m chunks =
    List.map
      (fun c0 -> if Chunk.equal c0 c then m else Sigma.value sigma c0)
      chunks

  let frame_lemmas phi obj loc params chunks =
    begin
      let prefix = Fun.debug phi in
      let sigma = Sigma.create () in
      List.iteri
        (fun i chunk ->
           List.iter
             (fun (name,triggers,conditions,m1,m2) ->
                let mem1 = assigned sigma chunk m1 chunks in
                let mem2 = assigned sigma chunk m2 chunks in
                let value1 = e_fun phi (params @ mem1) in
                let value2 = e_fun phi (params @ mem2) in
                let vars1 = F.vars value1 in
                let vars2 = F.vars value2 in
                let l_triggers =
                  if Vars.subset vars1 vars2 then
                    [ (Trigger.of_term value2 :: triggers ) ]
                  else
                  if Vars.subset vars2 vars1 then
                    [ (Trigger.of_term value1 :: triggers ) ]
                  else
                    [ (Trigger.of_term value1 :: triggers );
                      (Trigger.of_term value2 :: triggers ) ]
                in
                let l_name = Pretty_utils.sfprintf "%s_%s_%a%d"
                    prefix name Chunk.pretty chunk i in
                let l_lemma = F.p_hyps conditions (p_equal value1 value2) in
                Definitions.define_lemma {
                  l_kind = `Axiom ;
                  l_name ; l_types = 0 ;
                  l_triggers ;
                  l_forall = F.p_vars l_lemma ;
                  l_lemma = l_lemma ;
                  l_cluster = cluster () ;
                }
             ) (M.frames obj loc chunk)
        ) chunks
    end

  (* -------------------------------------------------------------------------- *)
  (* ---  Compound Loader                                                   --- *)
  (* -------------------------------------------------------------------------- *)

  module COMP_KEY =
  struct
    type t = int * compinfo
    let compare (r,c) (r',c') = if r=r' then Compinfo.compare c c' else r-r'
    let pretty fmt (r,c) = Format.fprintf fmt "%d:%a" r Compinfo.pretty c
  end

  module COMP = WpContext.Generator(COMP_KEY)
      (struct
        let name = M.name ^ ".COMP"
        type key = int * compinfo
        type data = lfun * chunk list

        let generate (r,c) =
          let x = Lang.freshvar ~basename:"p" (Lang.t_addr()) in
          let v = e_var x in
          let obj = C_comp c in
          let loc = M.of_region_pointer r obj v in (* t_pointer -> loc *)
          let domain = M.value_footprint obj loc in
          let result = Lang.tau_of_comp c in
          let lfun =
            Lang.generated_f ~result "Load%a_%s" pp_rid r (Lang.comp_id c)
          in
          (* Since its a generated it is the unique name given *)
          let xms,chunks,sigma = signature domain in
          let def = List.map
              (fun f ->
                 Cfield (f, KValue) ,
                 !loadrec sigma (object_of f.ftype) (M.field loc f)
              ) c.cfields in
          let dfun = Definitions.Function( result , Def , e_record def ) in
          Definitions.define_symbol {
            d_lfun = lfun ; d_types = 0 ;
            d_params = x :: xms ;
            d_definition = dfun ;
            d_cluster = cluster () ;
          } ;
          frame_lemmas lfun obj loc [v] chunks ;
          lfun , chunks

        let compile = Lang.local generate
      end)

  (* -------------------------------------------------------------------------- *)
  (* ---  Array Loader                                                      --- *)
  (* -------------------------------------------------------------------------- *)

  module ARRAY_KEY =
  struct
    type t = int * arrayinfo * Matrix.matrix
    let pretty fmt (r,_,m) =
      Format.fprintf fmt "%d:%a" r Matrix.NATURAL.pretty m
    let compare (r1,_,m1) (r2,_,m2) =
      if r1 = r2 then Matrix.NATURAL.compare m1 m2 else r1-r2
  end

  module ARRAY = WpContext.Generator(ARRAY_KEY)
      (struct
        open Matrix
        let name = M.name ^ ".ARRAY"
        type key = int * arrayinfo * Matrix.matrix
        type data = lfun * chunk list

        let generate (r,ainfo,(obj_e,ds)) =
          let x = Lang.freshvar ~basename:"p" (Lang.t_addr()) in
          let v = e_var x in
          let obj_a = C_array ainfo in
          let loc = M.of_region_pointer r obj_a v in (* t_pointer -> loc *)
          let domain = M.value_footprint obj_a loc in
          let result = Matrix.tau obj_e ds in
          let lfun =
            Lang.generated_f ~result "Array%a%s_%s"
              pp_rid r (Matrix.id ds) (Matrix.natural_id obj_e)
          in
          let prefix = Lang.Fun.debug lfun in
          let name = prefix ^ "_access" in
          let xmem,chunks,sigma = signature domain in
          let denv = Matrix.denv ds in
          let phi = e_fun lfun (v :: denv.size_val @ List.map e_var xmem) in
          let va = List.fold_left e_get phi denv.index_val in
          let ofs = e_sum denv.index_offset in
          let vm = !loadrec sigma obj_e (M.shift loc obj_e ofs) in
          let lemma = p_hyps denv.index_range (p_equal va vm) in
          let cluster = cluster () in
          Definitions.define_symbol {
            d_lfun = lfun ; d_types = 0 ;
            d_params = x :: denv.size_var @ xmem ;
            d_definition = Logic result ;
            d_cluster = cluster ;
          } ;
          Definitions.define_lemma {
            l_kind = `Axiom ;
            l_name = name ; l_types = 0 ;
            l_forall = F.p_vars lemma ;
            l_triggers = [[Trigger.of_term va]] ;
            l_lemma = lemma ;
            l_cluster = cluster ;
          } ;
          if denv.monotonic then
            begin
              let ns = List.map F.e_var denv.size_var in
              frame_lemmas lfun obj_a loc (v::ns) chunks
            end ;
          lfun , chunks

        let compile = Lang.local generate
      end)

  (* -------------------------------------------------------------------------- *)
  (* --- Loader                                                             --- *)
  (* -------------------------------------------------------------------------- *)

  let load_comp sigma comp loc =
    let r , p = M.to_region_pointer loc in
    let f , m = COMP.get (r,comp) in
    F.e_fun f (p :: memories sigma m)

  let load_array sigma a loc =
    let d = Matrix.of_array a in
    let r , p = M.to_region_pointer loc in
    let f , m = ARRAY.get (r,a,d) in
    F.e_fun f (p :: Matrix.size d @ memories sigma m)

  let loadvalue sigma obj loc =
    match obj with
    | C_int i -> M.load_int sigma i loc
    | C_float f -> M.load_float sigma f loc
    | C_pointer t -> snd @@ M.to_region_pointer @@ M.load_pointer sigma t loc
    | C_comp c -> load_comp sigma c loc
    | C_array a -> load_array sigma a loc

  let load sigma obj loc =
    let open Sigs in
    match obj with
    | C_int i -> Val (M.load_int sigma i loc)
    | C_float f -> Val (M.load_float sigma f loc)
    | C_pointer t -> Loc (M.load_pointer sigma t loc)
    | C_comp c -> Val (load_comp sigma c loc)
    | C_array a -> Val (load_array sigma a loc)

  let () = loadrec := loadvalue

  (* -------------------------------------------------------------------------- *)
  (* --- Initialized                                                        --- *)
  (* -------------------------------------------------------------------------- *)

  let isinitrec = ref (fun _ _ _ -> assert false)

  let initialization_lemma cluster name (sigma, obj, loc) (lfun, params) =
    let high = p_call lfun (List.map F.e_var params) in
    let low = M.is_init_range sigma obj loc e_one in
    let lemma = p_equiv high low in
    {
      l_assumed = true ;
      l_name = name ^ "_low" ; l_types = 0 ;
      l_forall = F.p_vars lemma ;
      l_triggers = [] ;
      l_lemma = lemma ;
      l_cluster = cluster ;
    }

  module IS_INIT_COMP = WpContext.Generator(COMP_KEY)
      (struct
        let name = M.name ^ ".IS_INIT_COMP"
        type key = int * compinfo
        type data = lfun * chunk list

        let generate (r,c) =
          let x = Lang.freshvar ~basename:"p" (Lang.t_addr()) in
          let v = e_var x in
          let obj = C_comp c in
          let loc = M.of_region_pointer r obj v in (* t_pointer -> loc *)
          let domain = M.init_footprint obj loc in
          let cluster = cluster () in
          (* Function Is_init *)
          let name =
            Format.asprintf "Is%s%a" (Lang.comp_init_id c) pp_rid r
          in
          let lfun = Lang.generated_p name in
          let xms,chunks,sigma = signature domain in
          let def = p_all
              (fun f -> !isinitrec sigma (object_of f.ftype) (M.field loc f))
              c.cfields
          in
          Definitions.define_symbol {
            d_lfun = lfun ; d_types = 0 ;
            d_params = x :: xms ;
            d_definition = Predicate(Def , def) ;
            d_cluster = cluster ;
          } ;
          (* Lemma for low-level view of the memory *)
          Definitions.define_lemma
            (initialization_lemma cluster name (sigma,obj,loc) (lfun,x::xms)) ;
          lfun , chunks

        let compile = Lang.local generate
      end)

  module ARRAYINIT = WpContext.Generator(ARRAY_KEY)
      (struct
        open Matrix
        let name = M.name ^ ".ARRAYINIT"
        type key = int * arrayinfo * Matrix.matrix
        type data = lfun * chunk list

        let generate (r,ainfo,(obj_e,ds)) =
          let x = Lang.freshvar ~basename:"p" (Lang.t_addr()) in
          let v = e_var x in
          let obj_a = C_array ainfo in
          let loc = M.of_region_pointer r obj_a v in (* t_pointer -> loc *)
          let domain = M.init_footprint obj_a loc in
          let name = Format.asprintf "IsInitArray%a%s_%s"
              pp_rid r (Matrix.id ds) (Matrix.natural_id obj_e)
          in
          let lfun = Lang.generated_p name in
          let xmem,chunks,sigma = signature domain in
          let denv = Matrix.denv ds in
          let ofs = e_sum denv.index_offset in
          let vm = !isinitrec sigma obj_e (M.shift loc obj_e ofs) in
          let def = p_forall denv.index_var (p_hyps denv.index_range vm) in
          let cluster = cluster () in
          Definitions.define_symbol {
            d_lfun = lfun ; d_types = 0 ;
            d_params = x :: denv.size_var @ xmem ;
            d_definition = Predicate (Def, def) ;
            d_cluster = cluster ;
          } ;
          (* Lemma for low-level view of the memory *)
          Definitions.define_lemma
            (initialization_lemma cluster name
               (sigma, obj_a, loc)
               (lfun, x :: denv.size_var @ xmem)) ;
          lfun , chunks

        let compile = Lang.local generate
      end)

  let initialized_comp sigma comp loc =
    let r , p = M.to_region_pointer loc in
    let f , m = IS_INIT_COMP.get (r,comp) in
    F.p_call f (p :: memories sigma m)

  let initialized_array sigma a loc =
    let d = Matrix.of_array a in
    let r , p = M.to_region_pointer loc in
    let f , m = ARRAYINIT.get (r,a,d) in
    F.p_call f (p :: Matrix.size d @ memories sigma m)

  let initialized_loc sigma obj loc =
    match obj with
    | C_int _ | C_float _ | C_pointer _ -> p_bool (M.is_init_atom sigma loc)
    | C_comp ci -> initialized_comp sigma ci loc
    | C_array a -> initialized_array sigma a loc

  let () = isinitrec := initialized_loc

  let initialized sigma = function
    | Rloc(obj, loc) -> initialized_loc sigma obj loc
    | Rrange(loc, obj, Some low, Some up) ->
        let x = Lang.freshvar ~basename:"i" Lang.t_int in
        let v = e_var x in
        let hyps = [ p_leq low v ; p_leq v up] in
        let loc = M.shift loc obj v in
        p_forall [x] (p_hyps hyps (initialized_loc sigma obj loc))
    | Rrange(_l, _, low, up) ->
        Wp_parameters.abort ~current:true
          "Invalid infinite range @[<hov 2>+@,(%a@,..%a)@]"
          Vset.pp_bound low Vset.pp_bound up

  (* -------------------------------------------------------------------------- *)
  (* --- Havocs                                                             --- *)
  (* -------------------------------------------------------------------------- *)

  let gen_havoc_length get_domain s obj loc length =
    let ps = ref [] in
    Domain.iter
      (fun chunk ->
         let pre = Sigma.value s.pre chunk in
         let post = Sigma.value s.post chunk in
         let tau = Chunk.tau_of_chunk chunk in
         let basename = Chunk.basename_of_chunk chunk ^ "_undef" in
         let fresh = F.e_var (Lang.freshvar ~basename tau) in
         let havoc = M.havoc obj loc ~length chunk ~fresh ~current:pre in
         ps := Set(post,havoc) :: !ps
      ) (get_domain obj loc) ; !ps

  let havoc_length = gen_havoc_length M.value_footprint
  let havoc seq obj loc = havoc_length seq obj loc F.e_one

  let havoc_init_length = gen_havoc_length M.init_footprint
  let havoc_init seq obj loc = havoc_init_length seq obj loc F.e_one

  let set_init_length s obj loc length =
    let ps = ref [] in
    Domain.iter
      (fun chunk ->
         let pre = Sigma.value s.pre chunk in
         let post = Sigma.value s.post chunk in
         let set = M.set_init obj loc ~length chunk ~current:pre in
         ps := Set(post,set) :: !ps
      ) (M.init_footprint obj loc) ; !ps

  let set_init seq obj loc = set_init_length seq obj loc F.e_one

  (* -------------------------------------------------------------------------- *)
  (* --- Stored & Copied                                                    --- *)
  (* -------------------------------------------------------------------------- *)

  let updated_init_atom seq loc value =
    let new_value = e_or [M.is_init_atom seq.pre loc ; value ] in
    let chunk_init,mem_init = M.set_init_atom seq.pre loc new_value in
    Set(Sigma.value seq.post chunk_init,mem_init)

  let updated_atom seq obj loc value =
    let phi_store sigma = match obj with
      | C_int i -> M.store_int sigma i
      | C_float f -> M.store_float sigma f
      | C_pointer ty -> M.store_pointer sigma ty
      | _ -> failwith "MemLoader updated_atom called on a non atomic type"
    in
    let chunk_store,mem_store = phi_store seq.pre loc value in
    Set(Sigma.value seq.post chunk_store,mem_store)

  let stored seq obj loc value =
    match obj with
    | C_int _ | C_float _ | C_pointer _ ->
        [ updated_atom seq obj loc value ; updated_init_atom seq loc e_true ]
    | C_comp _ | C_array _ ->
        let set_value = Set(loadvalue seq.post obj loc, value) in
        set_value :: havoc seq obj loc @ set_init seq obj loc

  let copied s obj p q = stored s obj p (loadvalue s.pre obj q)

  (* -------------------------------------------------------------------------- *)
  (* --- Assigned                                                           --- *)
  (* -------------------------------------------------------------------------- *)

  let assigned_loc seq obj loc =
    match obj with
    | C_int _ | C_float _ | C_pointer _ ->
        let value = Lang.freshvar ~basename:"v" (Lang.tau_of_object obj) in
        let init = Lang.freshvar ~basename:"i" (Lang.init_of_object obj) in
        [ updated_init_atom seq loc (e_var init) ;
          updated_atom seq obj loc (e_var value) ]
    | C_comp _ | C_array _ ->
        havoc seq obj loc @ havoc_init seq obj loc

  let assigned_range s obj l a b =
    havoc_length s obj (M.shift l obj a) (e_range a b) @
    havoc_init_length s obj (M.shift l obj a) (e_range a b)

  let assigned seq obj sloc =
    Assert (M.monotonic_init seq.pre seq.post) ::
    match sloc with
    | Sloc loc -> assigned_loc seq obj loc
    | Sdescr(xs,loc,condition) ->
        let ps = ref [] in
        Domain.iter
          (fun c ->
             let m1 = Sigma.value seq.pre c in
             let m2 = Sigma.value seq.post c in
             let p,separated,equal = M.eqmem_forall obj loc c m1 m2 in
             let sep_from_all = F.p_forall xs (F.p_imply condition separated) in
             let phi = F.p_forall p (F.p_imply sep_from_all equal) in
             ps := Assert phi :: !ps
          ) (domain obj loc) ;
        !ps
    | Sarray(loc,obj,n) ->
        assigned_range seq obj loc e_zero (e_int (n-1))
    | Srange(loc,obj,u,v) ->
        let a = match u with Some a -> a | None -> e_zero in
        let b = match v with Some b -> b | None -> M.last seq.pre obj loc in
        assigned_range seq obj loc a b

  (* -------------------------------------------------------------------------- *)

end
