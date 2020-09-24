(**************************************************************************)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2016                                               *)
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
(* --- Value Memory Model                                                 --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types
open Cil_datatype
open Ctypes
open Lang
open Lang.F
open Sigs
open Definitions

module L = Qed.Logic

let dkey = Wp_parameters.register_category "value" (* Debugging key *)
let debug fmt = Wp_parameters.debug ~dkey fmt
let not_yet fmt = Wp_parameters.not_yet_implemented fmt
let not_yet_base = not_yet "Base %a. Only Null and Var implemented." Base.pretty
let not_yet_obj = fun obj -> not_yet "Logic type %a." Ctypes.pp_object obj

let dkey = Wp_parameters.register_category "value+flow"
let debug_flow fmt = Wp_parameters.debug ~dkey fmt

(* let dkey = Wp_parameters.register_category "value+eva"
 * let debug_eva fmt = Wp_parameters.debug ~dkey fmt *)

let datatype = "MemValue"

let t_addr = MemMemory.t_addr

(* -------------------------------------------------------------------------- *)
(* ---  Utilities                                                         --- *)
(* -------------------------------------------------------------------------- *)

let a_null = MemMemory.a_null     (* { base = 0; offset = 0 } *)
let a_base = MemMemory.a_base     (* p -> p.offset *)
let a_offset = MemMemory.a_offset (* p -> p.base *)
let a_global = MemMemory.a_global (* b -> { base = b; offset = 0 } *)
let a_shift = MemMemory.a_shift   (* p k -> { p with offset = p.offset + k } *)
let a_addr = MemMemory.a_addr     (* b k -> { base = b; offset = k } *)

let cluster_dummy () = Definitions.cluster ~id:"Value" ~title:"MemValue" ()

(* Wp utilities *)
module Cstring =
struct
  include Cstring

  let str_cil ~eid cstr =
    let enode = match cstr with
      | C_str str -> Const (CStr str)
      | W_str wstr -> Const (CWStr wstr)
    in {
      eid = eid;
      enode = enode;
      eloc = Location.unknown;
    }
end

(*
let flow f l = (* TODO: USE ONE DAY *)
  let aux b acc =
    let cond = F.e_eq (a_base l.loc_t) (F.e_int (Base.id b)) in
    F.e_if cond (f l b) acc
  in
  V.fold_bases aux l.loc_v (F.e_false)
   *)

(* Value utilities *)
module V = Cvalue.V
(* module V_Or_Uninitialized = Cvalue.V_Or_Uninitialized *)
(* module V_Offsetmap = Cvalue.V_Offsetmap *)

module Base =
struct
  include Base

  let bitsize_from_validity = function
    | Invalid -> Integer.zero
    | Empty -> Integer.zero
    | Known (_, m)
    | Unknown (_, _, m) -> Integer.succ m
    | Variable { max_allocable } -> Integer.succ max_allocable

  let size_from_validity b =
    Integer.(e_div (bitsize_from_validity b) eight)
end

module VState =
struct
  module M = Cvalue.Model
  let current : M.t ref = ref M.bottom
  let update () =
    try
      match WpContext.get_scope () with
      | Global -> assert false
      | Kf kf ->
          current := M.bottom;
          let vis = object
            inherit Cil.nopCilVisitor
            method !vstmt s =
              current := M.join (Db.Value.get_stmt_state s) !current;
              Cil.DoChildren
          end in
          ignore (Cil.visitCilFunction vis (Kernel_function.get_definition kf))
    with | Invalid_argument _ | Kernel_function.No_Definition
      -> assert false (* since kf exists and has a definition *)
end

module Value :
sig
  type t
  type state = Cvalue.Model.t

  val top : t

  val null : t
  val literal : eid:int -> Cstring.cst -> int * t
  val cvar : state -> varinfo -> t

  val field : t -> fieldinfo -> t
  val shift : t -> c_object -> term -> t
  val base_addr : t -> t
  val load : state -> t -> c_object -> t

  val bases : t -> Base.t list

  val pretty : Format.formatter -> t -> unit
  val compare : t -> t -> int
end =
struct
  type t = Cvalue.V.t
  type state = Cvalue.Model.t

  let with_alarms = CilE.warn_none_mode
  let eval_expr state e = !Db.Value.eval_expr ~with_alarms state e

  let top = V.top

  let null = V.inject Base.null Ival.zero

  let literal ~eid cstr =
    let b = Base.of_string_exp (Cstring.str_cil ~eid cstr) in
    Base.id b, V.inject b Ival.zero

  let cvar : state -> varinfo -> t = fun state vi ->
    eval_expr state (Cil.mkAddrOfVi vi)

  let field : t -> fieldinfo -> t = fun v f ->
    let bsize = 8 * Ctypes.field_offset f |> Integer.of_int in
    let offs = Ival.inject_singleton bsize in
    Cvalue.V.shift offs v

  let shift : t -> c_object -> term -> t = fun v obj t ->
    let bsize = 8 * Ctypes.sizeof_object obj |> Integer.of_int in
    let offs = match F.repr t with
      | L.Kint z -> Ival.inject_singleton (Integer.mul bsize z)
      | _ -> Ival.top in
    Cvalue.V.shift offs v

  let base_addr : t -> t = function
    | V.Top _ -> V.top (* TODO: For now, just send Top *)
    | V.Map m ->
      let v = ref V.bottom in
      V.M.iter (fun b _ -> v := V.add b Ival.zero !v) m;
      !v

  let load : state -> t -> c_object -> t = fun state v obj ->
    let bsize = 8 * Ctypes.sizeof_object obj in
    let bits = Locations.loc_bytes_to_loc_bits v in
    let int_base = bsize |> Integer.of_int |> Int_Base.inject in
    let vloc = Locations.make_loc bits int_base in
    Cvalue.Model.find state vloc

  let bases : t -> Base.t list = fun v ->
    try
      V.fold_bases
        (fun b acc -> b :: acc)
        v []
    with Abstract_interp.Error_Top -> []

  let pretty = V.pretty
  let compare = V.compare
end


(* -------------------------------------------------------------------------- *)
(* ---  Model                                                             --- *)
(* -------------------------------------------------------------------------- *)


(* -------------------------------------------------------------------------- *)
(* ---  Model Parameters                                                  --- *)
(* -------------------------------------------------------------------------- *)

let configure () =
  if not (Db.Value.is_computed ()) then
    Warning.error ~source:"Value Model"
      "A previous Value analysis is needed by this memory model.";
  let orig_pointer = Context.push Lang.pointer (fun _ -> t_addr) in
  let rollback () =
    Context.pop Lang.pointer orig_pointer;
  in
  rollback


(* -------------------------------------------------------------------------- *)
(* ---  Chunk                                                             --- *)
(* -------------------------------------------------------------------------- *)

type chunk =
  | M_int
  | M_char
  | M_float
  | M_base of Base.t

module Chunk =
struct
  type t = chunk
  let self = "MemValue.Chunk"
  let hash = function
    | M_int -> 1
    | M_char -> 2
    | M_float -> 3
    | M_base b -> 5 * Base.hash b
  let equal c1 c2 = match c1, c2 with
    | M_base b1, M_base b2 -> Base.equal b1 b2
    | _ -> c1 = c2
  let compare c1 c2 = match c1, c2 with
    | M_base b1, M_base b2 -> Base.compare b1 b2
    | _ -> Stdlib.compare c1 c2
  let pretty fmt c = match c with
    | M_int -> Format.pp_print_string fmt "Mint"
    | M_char -> Format.pp_print_string fmt "Mchar"
    | M_float -> Format.pp_print_string fmt "Mfloat"
    | M_base b -> Base.pretty fmt b
  let tau_of_chunk = function
    | M_int | M_char -> L.Array (t_addr, L.Int)
    | M_float -> L.Array (t_addr, L.Real)
    | M_base _ -> L.Array (L.Int, t_addr)
  let basename_of_chunk c = match c with
    | M_int -> "Mint00"
    | M_char -> "Mchar"
    | M_float -> "Mfloat"
    | M_base b -> match b with
      | Base.Null -> "Mnull"
      | Base.Var (vi, _) -> Format.sprintf "Mvar_%s" (LogicUsage.basename vi)
      | Base.String (eid, _) -> Format.sprintf "MStr_%d" eid
      | b -> not_yet_base b
  let is_framed c = match c with
    | M_int | M_char | M_float -> false
    | M_base b ->
        try
          match WpContext.get_scope () with
          | Global -> assert false
          | Kf kf ->
              Base.is_formal_or_local b (Kernel_function.get_definition kf)
      with Invalid_argument _ | Kernel_function.No_Definition ->
        assert false (* by context *)
end

module RegisterBase = WpContext.Static
    (struct
      let name = "MemValue.RegisterBase"
      type key = term (* of type int *)
      type data = Base.t
      include F
      let pretty = F.pp_term
    end)

let count = ref 0

module TermV = WpContext.Generator(Value)
    (struct
      let name = "MemValue.TermV"
      type key = Value.t
      type data = term (* of type addr *)

      let _base_id prefix v (base : term) =
        let name = prefix ^ "_id_lemma" in
        let equal b = F.p_equal base (F.e_int (Base.id b)) in
        let rec lemma = function
          | [] -> assert false
          | [ b ] -> equal b
          | b :: bs -> F.p_or (equal b) (lemma bs)
        in
        match Value.bases v with
        | [] -> ()
        | bs ->
          Definitions.define_lemma {
              l_kind = `Axiom;
              l_name = name; l_types = 0; l_triggers = []; l_forall = [];
              l_lemma = lemma bs;
              l_cluster = cluster_dummy ();
            }

      let compile_base _v =
        incr count;
        let prefix =
          Format.sprintf "Base_%d" !count in
        let var = Lang.freshvar ~basename:prefix Qed.Logic.Int in
        let base = e_var var in
        (* base_id prefix v base; *)
        base

      let compile_offset _ =
        let prefix =
          Format.sprintf "Offs" in
        let var = Lang.freshvar ~basename:prefix Qed.Logic.Int in
        e_var var

      let compile x = a_addr (compile_base x) (compile_offset x)
    end)

type loc = {
  loc_v : Value.t;
  loc_t : term; (* of type addr *)
}

module Heap = Qed.Collection.Make(Chunk)
module Sigma = Sigma.Make(Chunk)(Heap)

(* -------------------------------------------------------------------------- *)
(* ---  Sigma                                                             --- *)
(* -------------------------------------------------------------------------- *)

type sigma = Sigma.t

(* -------------------------------------------------------------------------- *)
(* ---  State Pretty Printer                                              --- *)
(* -------------------------------------------------------------------------- *)

type state = chunk Tmap.t

let state : sigma -> state = fun sigma ->
  let s = ref Tmap.empty in
  Sigma.iter (fun c x -> s := Tmap.add (e_var x) c !s) sigma; !s

let imval c = Sigs.Mchunk (Pretty_utils.to_string Chunk.pretty c, KValue)

let lookup_lv _c _e = assert false (* TODO *)

let lookup s e =
  match Tmap.find e s with
  | exception Not_found -> Mterm
  | v -> imval v

let apply f s =
  let m = ref Tmap.empty in
  Tmap.iter (fun e c -> m := Tmap.add (f e) c !m) s; !m

let iter : (mval -> term -> unit) -> state -> unit = fun f s ->
  Tmap.iter (fun v c -> f (imval c) v) s

let heap domain state =
  Tmap.fold (fun m c w ->
      if Vars.intersect (F.vars m) domain
      then Heap.Map.add c m w else w
    ) state Heap.Map.empty

let rec diff c v1 v2 =
  if v1 == v2 then Bag.empty else
    match F.repr v2 with
    | L.Aset (m, k, v) ->
      let lv = lookup_lv c k in
      let upd = Mstore (lv, v) in
      Bag.append (diff c v1 m) upd
    | _ ->
      Bag.empty

let updates : (state sequence) -> Vars.t -> update Bag.t = fun seq domain ->
  let pool = ref Bag.empty in
  let pre = heap domain seq.pre in
  let post = heap domain seq.post in
  Heap.Map.iter2
    (fun c v1 v2 ->
       match v1, v2 with
       | Some v1, Some v2 -> pool := Bag.concat (diff c v1 v2) !pool
       | _ -> ()
    ) pre post;
  !pool

(* -------------------------------------------------------------------------- *)
(* ---  Location                                                          --- *)
(* -------------------------------------------------------------------------- *)

let m_int i = if Ctypes.is_char i then M_char else M_int

type segment = loc rloc

let vars : loc -> Vars.t = fun l -> F.vars l.loc_t

let occurs x l = Vars.mem x (vars l)

(* -------------------------------------------------------------------------- *)
(* ---  Pretty                                                            --- *)
(* -------------------------------------------------------------------------- *)

let pretty : Format.formatter -> loc -> unit = fun fmt l ->
  Format.fprintf fmt "[v: %a; t: %a]"
    Value.pretty l.loc_v F.pp_term l.loc_t

(* -------------------------------------------------------------------------- *)
(* ---  Basic Constructors                                                --- *)
(* -------------------------------------------------------------------------- *)

let null : loc = { (*QB: Correct *)
  loc_v = Value.null;
  loc_t = a_null;
}

let literal ~eid cstr = (*QB: Correct *)
  let bid, v = Value.literal ~eid cstr in
  {
    loc_v = v;
    loc_t = a_global (F.e_int bid);
  }

let cvar : varinfo -> loc = fun x ->
  debug_flow "[cvar] %a" Varinfo.pretty x;
  let state = !VState.current in
  let v = Value.cvar state x in
  {
    loc_v = v;
    loc_t = TermV.get v;
  }

(* -------------------------------------------------------------------------- *)
(* ---  Logic - Location conversion                                       --- *)
(* -------------------------------------------------------------------------- *)

(* [pointer_loc t] convert a logic term [t] into an abstract location.
   Currently, we only accept [t] of type [t_addr] and lose information about
   the abstract value for this location. *)
let pointer_loc : term -> loc = fun t ->
  debug_flow "locof %a" F.pp_term t;
  match F.typeof t with
  | tau when tau = t_addr -> {
      loc_v = Value.top;
      loc_t = t
    }
  | _ -> assert false

(* [pointer_val l] convert an abstract location [l] into a logic term. Since we
   can't express abstract values into the logic, only the logic part of the
   location is returned. *)
let pointer_val : loc -> term = fun l ->
  debug_flow "valof %a" pretty l;
  l.loc_t

(* -------------------------------------------------------------------------- *)
(* ---  Lifting                                                           --- *)
(* -------------------------------------------------------------------------- *)

let field : loc -> fieldinfo -> loc = fun l f ->
  debug_flow "field";
  let offs = Integer.of_int (Ctypes.field_offset f) in
  {
    loc_v = Value.field l.loc_v f;
    loc_t = a_shift l.loc_t (F.e_bigint offs);
  }

let shift : loc -> c_object -> term -> loc = fun l obj t ->
  debug_flow "shift %a" Ctypes.pp_object obj;
  let size = Integer.of_int (Ctypes.sizeof_object obj) in
  let offs = F.e_times size t in
  {
    loc_v = Value.shift l.loc_v obj t;
    loc_t = a_shift l.loc_t offs;
  }

let base_addr : loc -> loc = fun l ->
  debug_flow "base_addr";
  {
    loc_v = Value.base_addr l.loc_v;
    loc_t = a_addr (a_base l.loc_t) F.e_zero
  }

let block_length : sigma -> c_object -> loc -> term = fun _s _obj l ->
  let aux acc b =
    F.e_if
      (F.e_eq (F.e_int (Base.id b)) (a_base l.loc_t))
      (F.e_bigint (Base.size_from_validity (Base.validity b)))
      acc
  in
  List.fold_left aux F.e_false (Value.bases l.loc_v)

(* -------------------------------------------------------------------------- *)
(* ---  Casting                                                           --- *)
(* -------------------------------------------------------------------------- *)

let cast : c_object sequence -> loc -> loc = fun _obj l ->
  debug_flow "cast";
  l (* TODO: Check correctness *)

let loc_of_int : c_object -> term -> loc = fun _obj t ->
  debug "int: %a" F.pp_term t;
  if F.is_zero t then null else
    begin match F.repr t with
      | L.Kint _ -> (* TODO: Not correct *)
        let obj = Ctypes.(C_int (c_char ())) in
        {
          loc_v = Value.shift Value.null obj t;
          loc_t = a_shift null.loc_t t;
        }
      | _ -> Warning.error ~source:"Value Model"
               "Forbidden cast of int to pointer"
    end

let int_of_loc : c_int -> loc -> term = fun _ l ->
  a_offset l.loc_t

(* -------------------------------------------------------------------------- *)
(* ---  Memory Load                                                       --- *)
(* -------------------------------------------------------------------------- *)

let loadvalue : sigma -> c_object -> loc -> term = fun sigma _obj l ->
  let ite acc b =
    let cond = F.e_eq (a_base l.loc_t) (F.e_int (Base.id b)) in
    let load = F.e_get (Sigma.value sigma (M_base b)) (a_offset l.loc_t) in
    F.e_if cond load acc
  in
  try
    List.fold_left ite F.e_false (Value.bases l.loc_v)
  with Abstract_interp.Error_Top -> F.e_false

let loadpointer : c_object -> loc -> loc = fun obj loc ->
  let state = !VState.current in
  let v = Value.load state loc.loc_v obj in
  {
    loc_v = v;
    loc_t = TermV.get v;
  }

let load : sigma -> c_object -> loc -> loc value = fun sigma obj l -> match obj with
  | C_int i ->
    Val (F.e_get (Sigma.value sigma (m_int i)) l.loc_t)
  | C_float _ ->
    Val (F.e_get (Sigma.value sigma M_float) l.loc_t)
  | C_pointer _ ->
    Loc (loadpointer obj l)
  | _ -> not_yet_obj obj

(* Wrapper *)
let load sigma obj l = match load sigma obj l with
  | Val t as v ->
    debug_flow "load (%a) %a = Val (%a)"
      Ctypes.pp_object obj pretty l F.pp_term t;
      v
  | Loc l' as v ->
    debug_flow "load (%a) %a = Loc (%a)"
      Ctypes.pp_object obj pretty l pretty l';
    v

(* -------------------------------------------------------------------------- *)
(* ---  Memory Store                                                      --- *)
(* -------------------------------------------------------------------------- *)

let stored : sigma sequence -> c_object -> loc -> term -> equation list = fun seq _obj l e ->
  let ite acc b =
    let cond = F.p_equal (a_base l.loc_t) (F.e_int (Base.id b)) in
    let store =
      F.p_equal
        (Sigma.value seq.post (M_base b))
        (F.e_set (Sigma.value seq.pre (M_base b)) (a_offset l.loc_t) e)
    in
    F.p_if cond store acc
  in
  try
  let p = List.fold_left ite F.p_false (Value.bases l.loc_v) in
  [ Assert p ]
  with Abstract_interp.Error_Top -> [ Assert F.p_false ]

let updated s c l v =
  let m1 = Sigma.value s.pre c in
  let m2 = Sigma.value s.post c in
  [ Set( m2, (F.e_set m1 l.loc_t v)) ]

let stored : sigma sequence -> c_object -> loc -> term -> equation list = fun seq obj l e ->
  debug_flow "store %a" Ctypes.pp_object obj;
  match obj with
  | C_int i -> updated seq (m_int i) l e
  | C_float _ -> updated seq M_float l e
  | C_pointer _ -> stored seq obj l e
  | _ -> not_yet_obj obj

let copied : sigma sequence -> c_object -> loc -> loc -> equation list = fun seq obj ll lr ->
  debug_flow "copied";
  stored seq obj ll (loadvalue seq.pre obj lr)

let assigned : sigma sequence -> c_object -> loc sloc -> equation list = fun _ _ _ ->
  debug_flow "assigned";
  [ Assert F.p_true ]

(* -------------------------------------------------------------------------- *)
(* ---  Pointer Comparison                                                --- *)
(* -------------------------------------------------------------------------- *)

let is_null : loc -> pred = fun l ->
  p_equal l.loc_t a_null

let loc_delta l1 l2 =
  match F.is_equal (a_base l1.loc_t) (a_base l2.loc_t) with
  | L.Yes -> F.e_sub (a_offset l1.loc_t) (a_offset l2.loc_t)
  | L.Maybe | L.No ->
    Warning.error "Can only compare pointers with same base."

let base_eq l1 l2 = F.p_equal (a_base l1.loc_t) (a_base l2.loc_t)
let offset_cmp cmpop l1 l2 = cmpop (a_offset l1.loc_t) (a_offset l2.loc_t)

let loc_diff : c_object -> loc -> loc -> term = fun _obj l1 l2 ->
  debug_flow "loc_diff";
  loc_delta l1 l2
let loc_eq : loc -> loc -> pred = fun l1 l2 ->
  debug_flow "loc_eq";
  F.p_and (base_eq l1 l2) (offset_cmp F.p_equal l1 l2)
let loc_lt : loc -> loc -> pred = fun l1 l2 ->
  debug_flow "loc_lt";
  F.p_lt (loc_delta l1 l2) F.e_zero
let loc_leq : loc -> loc -> pred = fun l1 l2 ->
  debug_flow "loc_leq";
  F.p_leq (loc_delta l1 l2) F.e_zero
let loc_neq : loc -> loc -> pred = fun l1 l2 ->
  debug_flow "loc_neq";
  F.p_neq (loc_delta l1 l2) F.e_zero

(* -------------------------------------------------------------------------- *)
(* ---  Scope                                                             --- *)
(* -------------------------------------------------------------------------- *)

type alloc = ALLOC | FREE

let alloc_sigma : sigma -> varinfo list -> sigma = fun sigma xs ->
  let update sigma x =
    let havoc_chunk s (c : Base.t) =
      if Sigma.mem s (M_base c) then s
      else Sigma.havoc_chunk s (M_base c)
    in
    let state = !VState.current in
    let v = Value.cvar state x in
    List.fold_left havoc_chunk sigma (Value.bases v)
  in
  List.fold_left update sigma xs

let alloc_pred : sigma sequence -> varinfo list -> alloc -> pred list = fun _ _ _ -> [] (* TODO *)

 let alloc sigma xs =
    if xs = [] then sigma else alloc_sigma sigma xs

let scope : sigma sequence -> scope -> varinfo list -> pred list = fun seq scope xs ->
  match scope with
  | Enter ->
      alloc_pred seq xs ALLOC
  | Leave ->
      VState.update ();
      alloc_pred seq xs FREE

let global : sigma -> term (*addr*) -> pred = fun _sigma p ->
  match RegisterBase.get (a_base p) with
  | None -> F.p_false
  | Some c ->
    F.p_bool (F.e_bool (Chunk.is_framed (M_base c)))

(* -------------------------------------------------------------------------- *)
(* --- Segments                                                           --- *)
(* -------------------------------------------------------------------------- *)

type range =
  | LOC of term (*addr*) * term (*size*)
  | RANGE of term (*base*) * Vset.set (*range offset*)

let range = function
  | Rloc (obj, l) ->
    LOC (l.loc_t, F.e_int (Ctypes.sizeof_object obj))
  | Rrange (l, obj, Some a, Some b) ->
    let l' = shift l obj a in
    let n = e_fact (Ctypes.sizeof_object obj) (F.e_range a b) in
    LOC (l'.loc_t , n)
  | Rrange (l,_obj,None,None) ->
    RANGE (a_base l.loc_t, Vset.range None None)
  | Rrange (l,obj,Some a,None) ->
      let se = Ctypes.sizeof_object obj in
      RANGE (a_base l.loc_t, Vset.range (Some (e_fact se a)) None)
  | Rrange (l,obj,None,Some b) ->
      let se = Ctypes.sizeof_object obj in
      RANGE (a_base l.loc_t, Vset.range None (Some (e_fact se b)))

let range_set = function
  | LOC (l, n) ->
    let a = a_offset l in
    let b = e_add a n in
    a_base l, Vset.range (Some a) (Some b)
  | RANGE (base, set) -> base, set

(* -------------------------------------------------------------------------- *)
(* ---  Validity                                                          --- *)
(* -------------------------------------------------------------------------- *)

let vset_from_validity = function
  | Base.Empty -> Vset.empty
  | Base.Invalid -> Vset.singleton F.e_zero
  | Base.Known (min_valid, max_valid)

  | Base.Unknown (min_valid, Some max_valid, _) ->
    (* valid between min_valid .. max_valid inclusive *)
    Vset.range (Some (F.e_bigint min_valid)) (Some (F.e_bigint max_valid))
  | Base.Variable { Base.min_alloc = min_valid } ->
    (* valid between 0 .. min_valid inclusive *)
    Vset.range (Some F.e_zero) (Some (F.e_bigint min_valid))
  | Base.Unknown (_, None, _) -> Vset.empty

let r_valid acs r =
  let for_writing = match acs with | RW | OBJ -> true | RD -> false in
  let base, set = range_set r in
  match RegisterBase.get base with
  | None -> F.p_false (* For now. *)
  | Some base ->
    if for_writing && (Base.is_read_only base) then
      F.p_false
    else
      Vset.subset set (vset_from_validity (Base.validity base))

let valid : sigma -> acs -> segment -> pred = fun _s acs seg ->
    r_valid acs (range seg)

(* -------------------------------------------------------------------------- *)
(* ---  Segment Inclusion                                                 --- *)
(* -------------------------------------------------------------------------- *)

let r_included r1 r2 = match r1, r2 with
  (* | LOC (l1, n1), LOC (l2, n2) -> p_call p_included [l1;n1;l2;n2] *)
  | _ ->
    let base1, set1 = range_set r1 in
    let base2, set2 = range_set r2 in
    p_and (p_equal base1 base2) (Vset.subset set1 set2)

let included : segment -> segment -> pred = fun s1 s2 ->
  r_included (range s1) (range s2)

(* -------------------------------------------------------------------------- *)
(* ---  Segment Separation                                                --- *)
(* -------------------------------------------------------------------------- *)

let r_separated r1 r2 = match r1, r2 with
  (* | LOC (l1, n1), LOC (l2, n2) -> p_call p_separated [l1;n1;l2;n2] *)
  | _ ->
    let base1, set1 = range_set r1 in
    let base2, set2 = range_set r1 in
    p_imply (p_equal base1 base2) (Vset.disjoint set1 set2)

let separated : segment -> segment -> pred = fun s1 s2 ->
  r_separated (range s1) (range s2)

(* -------------------------------------------------------------------------- *)
(* ---  Domain                                                            --- *)
(* -------------------------------------------------------------------------- *)

let domain : c_object -> loc -> Sigma.domain = fun obj l -> match obj with
  | C_int i -> Heap.Set.singleton (m_int i)
  | C_float _ -> Heap.Set.singleton M_float
  | C_pointer _ ->
    begin try
      List.fold_left (fun acc b -> Heap.Set.add (M_base b) acc)
        Heap.Set.empty (Value.bases l.loc_v)
    with Abstract_interp.Error_Top -> Heap.Set.empty end
  | _ -> not_yet_obj obj

(* -------------------------------------------------------------------------- *)


let initialized _sigma _l = F.p_true (* todo *)
let is_well_formed _ = F.p_true (* todo *)
let base_offset _loc = assert false (** TODO *)
type domain = Sigma.domain
let no_binder = { bind = fun _ f v -> f v }
let configure_ia _ = no_binder (* todo *)
let hypotheses x = x (* todo *)
let frame _sigma = [] (* todo *)
let invalid = fun _ _ -> F.p_true (* TODO *)
