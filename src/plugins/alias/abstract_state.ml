(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2023                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)

open Graph

open Cil_types

open Cil_datatype

open Simplified

module VSet = Datatype.Int.Set
module VMap = Datatype.Int.Map

module Lval = Simplified.Simplified_lval
module LSet = Simplified.Simplified_lset
module LMap = Simplified.Simplified_lmap

module G = Persistent.Digraph.Concrete(Datatype.Int)

module V = G.V

(* like LMap, but organized with offset and specialized functions *)
module LLMap =
struct
  module OMap = Offset.Map
  (* each t is a map (lhost,NoOffset) -> offset -> V.t *)
  type t = (V.t OMap.t) LMap.t

  let empty : t = LMap.empty

  let mem (lv:Lval.t) (m:t) =
    let lv, off = Lval.removeOffsetLval lv in
    try
      OMap.mem off (LMap.find lv m)
    with
      Not_found -> false

  let find (lv:Lval.t) (m:t) : V.t =
    let lv, off = Lval.removeOffsetLval lv in
    OMap.find off (LMap.find lv m)

  let add (lv:Lval.t) (v:V.t) (m:t) :t  =
    let lv, off = Lval.removeOffsetLval lv in
    let mo = try LMap.find lv m with Not_found -> OMap.empty in
    LMap.add lv (OMap.add off v mo) m

  let remove (lv:Lval.t) (m:t) :t =
    let lv, off = Lval.removeOffsetLval lv in
    let mo = try LMap.find lv m with Not_found -> OMap.empty in
    let res = OMap.remove off mo in
    if OMap.is_empty res
    then
      LMap.remove lv m
    else
      LMap.add lv res m

  let _from_lmap (lm: V.t LMap.t) : t =
    LMap.fold
      (fun lv v acc -> add lv v acc)
      lm
      LMap.empty

  let _to_lmap (m:t) : V.t LMap.t =
    LMap.fold
      (fun lv mo acc ->
         OMap.fold
           (fun o v acc ->
              let lv = Lval.addOffsetLval o lv in
              LMap.add lv v acc
           )
           mo
           acc
      )
      m
      LMap.empty

  let iter (f_iter: Lval.t -> V.t -> unit) (m:t) : unit =
    LMap.iter
      (fun lv mo ->
         OMap.iter
           (fun o v ->
              let lv = Lval.addOffsetLval o lv in
              f_iter lv v
           )
           mo
      )
      m

  let fold (f_fold: Lval.t -> V.t -> 'a -> 'a ) (m:t) (init:'a) : 'a =
    LMap.fold
      (fun lv mo acc ->
         OMap.fold
           (fun o v acc ->
              let lv = Lval.addOffsetLval o lv in
              f_fold lv v acc
           )
           mo
           acc
      )
      m
      init

  let map (f_map: V.t -> V.t ) (m:t) : 'a =
    LMap.map
      (fun mo ->
         OMap.map
           f_map
           mo
      )
      m

  let _mapi (f_mapi: Lval.t -> V.t -> V.t ) (m:t) : 'a =
    LMap.mapi
      (fun lv mo ->
         OMap.mapi
           (fun o v ->
              let lv = Lval.addOffsetLval o lv in
              f_mapi lv v
           )
           mo
      )
      m

  let pretty fmt (m:t) =
    LMap.iter
      (fun lv mo ->
         OMap.iter
           (fun o v -> let lv =  Lval.addOffsetLval o lv in Format.fprintf fmt "(lval=%a -> id= %d)@." Lval.pretty lv v)
           mo
      )
      m


  (* specialized functions *)
  let rec is_sub_offset o1 o2 =
    match (o1,o2) with
      NoOffset, _ -> true
    | Index (e1,o1), Index(e2,o2) when Exp.equal e1 e2 -> is_sub_offset o1 o2
    | Field (f1,o1), Field(f2,o2) when Fieldinfo.equal f1 f2 ->  is_sub_offset o1 o2
    | _ -> false

  (* finds all the lval lv1 apearing in [m] such as there exists an offset o1 and lv1 = lv+o1 *)
  let _find_lower_offsets (lv:Lval.t) (m:t) : V.t LMap.t =
    let lv, off = Lval.removeOffsetLval lv in
    let mo = try LMap.find lv m with Not_found -> OMap.empty in
    let f_filter o _v = is_sub_offset off o in
    let mo = OMap.filter f_filter mo in
    OMap.fold
      (fun o v acc -> let lv = Lval.addOffsetLval o lv in LMap.add lv v acc)
      mo
      LMap.empty

  (* finds all the lval lv1 apearing in [m] such as there exists an offset o1 and lv1 + o1 = lv *)
  let find_upper_offsets (lv:Lval.t) (m:t) : V.t LMap.t =
    let lv, off = Lval.removeOffsetLval lv in
    let mo = try LMap.find lv m with Not_found -> OMap.empty in
    let f_filter o _v = is_sub_offset o off in
    let mo = OMap.filter f_filter mo in
    OMap.fold
      (fun o v acc -> let lv = Lval.addOffsetLval o lv in LMap.add lv v acc)
      mo
      LMap.empty

  let rec is_indexed_offset o1 o2 =
    match (o1,o2) with
      NoOffset, Index(_,NoOffset) -> true
    | Index (e1,o1), Index(e2,o2) when Exp.equal e1 e2 -> is_indexed_offset o1 o2
    | Field (f1,o1), Field(f2,o2) when Fieldinfo.equal f1 f2 ->  is_indexed_offset o1 o2
    | _ -> false

  (* finds all the lval lv1 apearing in [m] such as there exists an index c  such as lv1 = lv[c] *)
  let _find_indexed_offsets (lv:Lval.t) (m:t) : V.t LMap.t =
    let lv, off = Lval.removeOffsetLval lv in
    let mo = try LMap.find lv m with Not_found -> OMap.empty in
    let f_filter o _v = is_indexed_offset off o in
    let mo = OMap.filter f_filter mo in
    OMap.fold
      (fun o v acc -> let lv = Lval.addOffsetLval o lv in LMap.add lv v acc)
      mo
      LMap.empty


end

module type S =
sig

  (* see .mli for coments *)
  type t

  val get_graph: t -> G.t

  val get_lval_set : G.V.t -> t -> LSet.t

  val pretty : ?debug:bool -> Format.formatter -> t -> unit

  val print_dot : string -> t -> unit

  val find_vertex : lval -> t -> G.V.t

  val find_aliases : lval -> t -> LSet.t

  val find_transitive_closure : lval -> t -> LSet.t list

  val is_included : t -> t -> bool

end

type t = {
  graph : G.t;
  pending : VSet.t VMap.t ; (* pending(v) is the set of vertices v' that could be aliased to v if v becomes/ is detected as a pointer *)
  lmap : LLMap.t ; (* lmap(lv) is a table [offset->v] where the vertex v corresponding to lval (lv+offset), in other words (lv+offset) is in label(v) *)
  vmap : LSet.t VMap.t ;(* reverse of lmap *)
  cmpt : Int.t ; (* counter to create new vertex *)
  (* collapsed : VSet.t (\* arrays that are collapsed because of non-constant accesses. All aliased arrays are collapsed *\) *)
}


(* find functions *)
let find_lset (v:V.t) (x:t) =
  try VMap.find v x.vmap
  with Not_found -> LSet.empty

let find_aliases (lv:lval) (x:t) =
  let lv : Lval.t = Lval.from_lval lv in
  try find_lset (LLMap.find lv x.lmap) x
  with Not_found -> LSet.empty

let get_graph (x:t) = x.graph

(* renamed for the interface *)
let get_lval_set = find_lset


(* printing functions *)

let print_debug fmt (x:t) =
  Format.fprintf fmt "@[<hov 2>List of vertices: @.";
  G.iter_vertex (fun v -> Format.fprintf fmt "(id=%d LSet= %a)@." v LSet.pp_debug (find_lset v x)) x.graph;
  Format.fprintf fmt "@]@.@[<hov 2>List of edges: @.";
  G.iter_edges (fun v1 v2 -> Format.fprintf fmt "(%d -> %d)@." v1 v2) x.graph;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "@[<hov 2>Pending: @.";
  VMap.iter (fun v vs -> Format.fprintf fmt "(id=%d pending= %a)@." v VSet.pretty vs) x.pending;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "@[<hov 2>LMap: @.";
  LLMap.pretty fmt x.lmap;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "@[<hov 2>VMap: @.";
  VMap.iter (fun v ls -> Format.fprintf fmt "(id = %d -> lset= %a)@." v LSet.pp_debug ls) x.vmap;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "cmpt: %d@." x.cmpt
(* let collapsed_lval : LSet.t = VSet.fold (fun v acc  -> LSet.union acc (try VMap.find v x.vmap with Not_found -> LSet.empty))  x.collapsed LSet.empty in
 * Format.fprintf fmt "collapsed arrays: %a@." LSet.pretty collapsed_lval *)

let print_aliases fmt (x:t) =
  let iter_vmap v set_lv =
    if G.mem_vertex x.graph v then
      match G.succ x.graph v with
        [] -> ()
      | [_] ->
        begin
          let set_pred = ref LSet.empty in
          G.iter_pred
            (fun v -> set_pred := LSet.union !set_pred (VMap.find v x.vmap))
            x.graph
            v;
          if LSet.cardinal set_lv + LSet.cardinal !set_pred >= 2
          then
            Format.fprintf fmt "{%a%a} are aliased@."
              (fun fmt s ->
                 LSet.iter
                   (fun lv -> Format.fprintf fmt "%a; " Lval.pretty lv)
                   s
              )
              set_lv
              (fun fmt s ->
                 LSet.iter
                   (fun lv -> Format.fprintf fmt "*%a; " Lval.pretty lv)
                   s
              )
              !set_pred
        end
      | _ -> Options.fatal "this should not happen"
  in
  Format.fprintf fmt "@[<hov 2><list of may-alias>@.";
  VMap.iter iter_vmap x.vmap;
  Format.fprintf fmt "<end of list>@]@."(* ;
                                         * let collapsed_lval : LSet.t = VSet.fold (fun v acc  -> LSet.union acc (try VMap.find v x.vmap with Not_found -> LSet.empty))  x.collapsed LSet.empty in
                                         * if not (LSet.is_empty collapsed_lval) then
                                         *   Format.fprintf fmt "collapsed arrays: %a@." LSet.pretty collapsed_lval *)

let pretty ?(debug=false) =
  if debug then
    print_debug
  else
    print_aliases


(** invariants of type t must be true before and after each functon call *)
let assert_invariants (x:t) : unit =
  (* check that all vertex of the graph have entries in pending and
     vmap, and are integer between 0 and cmpt, and have at most 1
     successor *)
  let assert_vertex (v:V.t) =
    assert (v >= 0);
    assert (v < x.cmpt);
    assert (VMap.mem v x.pending);
    assert (VMap.mem v x.vmap);
    assert (List.length (G.succ x.graph v) <= 1)
  in
  G.iter_vertex assert_vertex x.graph;
  let assert_edge v1 v2 =
    assert (G.mem_vertex x.graph v1);
    assert (G.mem_vertex x.graph v2)
  in
  G.iter_edges assert_edge x.graph;
  let assert_lmap (lv:Lval.t) (v:V.t) =
    assert (G.mem_vertex x.graph v);
    assert (LSet.mem lv (VMap.find v x.vmap))
  in
  LLMap.iter assert_lmap x.lmap;
  let assert_vmap (_:V.t) (ls:LSet.t) =
    assert (LSet.fold (fun lv acc -> acc && LLMap.mem lv x.lmap) ls true)
  in
  VMap.iter assert_vmap x.vmap(* ;
                               * let assert_collapsed (v:V.t) =
                               *   assert (G.mem_vertex x.graph v);
                               *   match G.succ x.graph v with
                               *     [v'] ->
                               *     begin
                               *       let set_v = find_lset v x in
                               *       let set_v' = find_lset v' x in
                               *       (\* check that for each lvl lv of v, lv[0] belongs to succ(v) *\)
                               *       LSet.iter
                               *         (fun lv ->
                               *            assert (LSet.mem (first_index lv) set_v')
                               *         )
                               *         set_v
                               *     end
                               *   | _ -> assert false
                               * in
                               * VSet.iter assert_collapsed x.collapsed *)

(* for debuging, remove this function before last deliverable *)
let assert_invariants x =
  try assert_invariants x
  with
    Assert_failure f ->  (Format.printf "DEBUG FAILED INVARIANTS@.%a@." (pretty ~debug:true) x; raise (Assert_failure f))


(* find functions, part 2 *)
let rec closure_find_lset (v:V.t) (x:t) =
  match G.succ x.graph v with
    [] -> [find_lset v x]
  | [v_next] -> (find_lset v x)::(closure_find_lset v_next x)
  | _ -> Options.fatal ("this shall not happen (invariant broken)")

let find_transitive_closure  (lv:lval) (x:t) =
  let lv: Lval.t = Lval.from_lval lv in
  assert_invariants x;
  try
    let v = (LLMap.find lv x.lmap) in
    closure_find_lset v x
  with
    Not_found -> []
(* TODO : what about offsets ? *)


(* find the vertex corresponding to lv+o in x, where lv is in v *)
let _redirect_offset (v:V.t) (o:offset) (x:t) : V.t option =
  let setv = find_lset v x in
  let res = ref None in
  LSet.iter
    (fun lv ->
       let lv = Lval.addOffsetLval o lv in
       try
         begin
           let v1 = LLMap.find lv x.lmap in
           match !res with
             Some v2 -> assert (V.equal v1 v2)
           | None -> res := Some v1
         end
       with
         Not_found -> ()
    )
    setv;
  !res


(* NOTE on "constant vertex": a constant vertex represents an unamed
   scalar value (type bottom in steensgaard's paper), or the address
   of a variable. It means that in [vmap], its associated LSet is
   empty.  By definition, constant vertex cannot be associated to a
   lval in [lmap] *)
let create_cst_vertex (x:t) : V.t * t =
  let new_v = x.cmpt in
  let new_g = G.add_vertex x.graph new_v in
  let new_pending = VMap.add new_v VSet.empty x.pending in
  let new_lmap = x.lmap in
  let new_vmap = VMap.add new_v LSet.empty x.vmap in
  new_v ,
  {
    graph = new_g ;
    pending = new_pending ;
    lmap = new_lmap ;
    vmap = new_vmap ;
    cmpt = x.cmpt+1(*  ;
                    * collapsed = x.collapsed *)
  }


(* find all the aliases of lv1 in x, for create_vertex *)
let find_all_aliases (lv1: Lval.t) (x: t) : LSet.t =

  let list_of_lval_to_be_searched : (Lval.t*offset) list =
    decompose_lval lv1
  in
  (* for each lval, find the set of aliases *)
  let f_map (lv,o) =
    try (VMap.find (LLMap.find lv x.lmap) x.vmap, o)
    with
      Not_found -> (LSet.empty,o)
  in
  let list_of_aliases : (LSet.t*offset) list =
    List.map f_map list_of_lval_to_be_searched
  in
  (*  for each lval of the Lset, add the offset and add it to the resulting set *)
  let f_fold_left (acc:LSet.t) (ls,o) =
    LSet.fold
      (fun lv acc -> let lv = Lval.addOffsetLval o lv in LSet.add lv acc)
      ls
      acc
  in
  List.fold_left
    f_fold_left
    (LSet.singleton lv1)
    list_of_aliases


(* returns the new vertex and the new graph *)
(* only for function find_or_create vertex *)
let create_vertex_simple (lv:Lval.t) (x:t) : V.t * t =
  let new_v = x.cmpt in
  let new_g = G.add_vertex x.graph new_v in
  let new_pending = VMap.add new_v VSet.empty x.pending in
  (* find all the alias of lv (because of offset) *)
  let set_of_aliases = find_all_aliases lv x in
  (* add all these aliases *)
  let new_lmap =
    LSet.fold
      (fun lv acc -> LLMap.add lv new_v acc)
      set_of_aliases
      x.lmap
  in
  let new_vmap = VMap.add new_v set_of_aliases x.vmap in

  let new_x =
    {
      graph = new_g ;
      pending = new_pending ;
      lmap = new_lmap ;
      vmap = new_vmap ;
      cmpt = x.cmpt+1 (* ;
                       * collapsed = x.collapsed *)
    }
  in
  assert_invariants new_x;
  match lv with
  | BLval (Var v, NoOffset) ->
    begin
      match v.vtype with
        TPtr _ ->
        (* then add a constant vertex *)
        let another_v, new_x = create_cst_vertex new_x in
        let new_g = G.add_edge new_x.graph new_v another_v in
        new_v, {new_x with graph= new_g}
      | _ ->   new_v ,new_x
    end
  | _ ->
    new_v , new_x

(* only for function find_or_create_vertex *)
let create_vertex_addr (lv:lval) (v:V.t) (x:t) : V.t *t =
  let va, x = create_vertex_simple (BAddrOf lv) x in
  let new_g =  G.add_edge x.graph va v in
  va, { x with graph=new_g}


(* (\* Replace all trailing array subscripts of an lval with zero indices. *\)
 * let rec shift_offsets lv loc =
 *   let lv, off = Lval.removeOffsetLval lv in
 *   match off with
 *   | Index _ ->
 *     let lv = shift_offsets lv loc in
 *     (\* since the offset has been removed at the start of the function, add a new
 *        0 offset to preserve the type of the lvalue. *\)
 *     Lval.addOffsetLval (Index (Cil.zero ~loc, NoOffset)) lv
 *   | NoOffset | Field _ -> Lval.addOffsetLval off lv
 *
 * let rec ptr_base ~loc exp =
 *   match exp.enode with
 *   | BinOp(op, lhs, _, _) ->
 *     (match op with
 *      (\* Pointer arithmetic: split pointer and integer parts *\)
 *      | MinusPI | PlusPI -> ptr_base ~loc lhs
 *      (\* Other arithmetic: treat the whole expression as pointer address *\)
 *      | MinusPP | PlusA | MinusA | Mult | Div | Mod
 *      | BAnd | BXor | BOr | Shiftlt | Shiftrt
 *      | Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr -> exp)
 *   (\* AddressOf: if it is an addressof array then replace all trailing offsets
 *      with zero offsets to get the base. *\)
 *   | AddrOf lv -> Cil.mkAddrOf ~loc (shift_offsets lv loc)
 *   (\* StartOf already points to the start of an array, return exp directly *\)
 *   | StartOf _ -> exp
 *   (\* Cast: strip cast and continue, then recast to original type. *\)
 *   | CastE _ ->
 *     let exp, casts = strip_casts exp in
 *     let base = ptr_base ~loc exp in
 *     add_casts casts base
 *   | Const _ | Lval _ | UnOp _ -> exp
 *   | SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _ | AlignOfE _
 *     -> assert false
 *
 * let ptr_base_and_base_addr ~loc e =
 *   let rec ptr_base_addr ~loc base =
 *     match base.enode with
 *     | AddrOf _ | StartOf _ | Const _ -> Cil.zero ~loc
 *     | Lval lv -> Cil.mkAddrOrStartOf ~loc lv
 *     | CastE _ -> ptr_base_addr ~loc (Cil.stripCasts base)
 *     | _ -> assert false
 *   in
 *   let base = ptr_base ~loc e in
 *   let base_addr  = ptr_base_addr ~loc base in
 *   base, base_addr *)

(* let list_arrays_to_be_collapsed = ref [] *)

(* let is_collapsed (lv:Lval.t) (x:t) =
 *   try
 *     let v = LLMap.find lv x.lmap in
 *     VSet.mem v x.collapsed
 *   with Not_found -> false *)

(* (\* warning, this function has a side effect on list_arrays_to_be_collapsed *\)
 * let normalize_lval (x:t) (lv1:Lval.t) : lval =
 *   let lv, off = Lval.removeOffsetLval lv1 in
 *   list_arrays_to_be_collapsed := [];
 *   let loc = Location.unknown in
 *   let rec normalize_offset (lvx:Lval.t) (o:offset) : offset =
 *     match o with
 *       NoOffset -> NoOffset
 *     | Field (f, ofs) ->
 *       let lvx = Lval.addOffsetLval (Field(f,NoOffset)) lvx in
 *       Field (f,normalize_offset lvx ofs)
 *     | Index (e, ofs) ->
 *       if is_collapsed lvx x
 *       then
 *         let lvx = first_index lvx in
 *         Index(Cil.zero ~loc, normalize_offset lvx ofs)
 *       else
 *         let e, b = normalize_index e in
 *         if not b
 *         then (\* then we need to collapse lvx *\)
 *           begin
 *             list_arrays_to_be_collapsed := lvx::!list_arrays_to_be_collapsed;
 *             let lvx = first_index lvx in
 *             Index(Cil.zero ~loc, normalize_offset lvx ofs)
 *           end
 *         else
 *           let lvx = Lval.addOffsetLval (Index(e,NoOffset)) lvx in
 *           Index(e, normalize_offset lvx ofs)
 *   in
 *   let off = normalize_offset lv off in
 *   Lval.addOffsetLval off lv *)


let diff_offset (lv1:Lval.t) (lv2:Lval.t) =
  let rec f_diff_offset o1 o2 =
    match o1, o2 with
      NoOffset, _ -> o2
    | Field (_,o1), Field(_,o2) -> f_diff_offset o1 o2
    | Index (_,o1), Index(_,o2) -> f_diff_offset o1 o2
    | _ -> assert false
  in
  let _, o1 = Lval.removeOffsetLval lv1
  and _, o2 = Lval.removeOffsetLval lv2
  in
  assert (LLMap.is_sub_offset o1 o2);
  f_diff_offset o1 o2

(* create_vertex_lval shall only be called by find_or_create_vertex *)
(* creates a new vertex for a lval, assuming it is not already present
   in the graph. If it is present, there will be bugs *)
let rec create_vertex_lval (blv:Lval.t) (x:t) : V.t * t =
  match blv with
    BNone -> Options.fatal "this should not happen"
  | BLval lv ->
    begin
      match lv with
        (Mem e, NoOffset) ->
        (* special case, when we also add another vertex and a points-to edge*)
        begin
          (* first find the vertex corresponding to e *)
          match Lval.from_exp e with
            BNone -> Options.fatal "This should not happen "
          | BLval lv1 ->
            (* find the vertex *)
            let v1, x = find_or_create_vertex (BLval lv1) x in
            (* then creates a vertex for bvl *)
            let v2, x = create_vertex_simple blv x in
            (* finally add a points-to edge between v1 and v2 *)
            let new_graph = G.add_edge x.graph v1 v2 in
            v2, {x with graph = new_graph }

          | BAddrOf _ -> Options.fatal "*(&x) not allowed"
        end
      | _ -> create_vertex_simple blv x
    end
  | BAddrOf lv ->
    let v1, x = find_or_create_vertex (BLval lv) x in
    create_vertex_addr lv v1 x

(* find the vertex of an lval *)
and find_or_create_vertex (lv:Lval.t) (x:t) : V.t * t =
  try  (LLMap.find lv x.lmap, x)
  with
    Not_found ->
    begin
      (* try to find if an alias already exists in x *)
      let map_predecessors :V.t LMap.t =  LLMap.find_upper_offsets lv x.lmap in
      (* for any predecessor, find all its aliases and then look for potential existing vertex *)
      let f_fold_lmap lvx vx acc =
        let set_aliases = VMap.find vx x.vmap in
        if LSet.cardinal set_aliases > 1
        then
          let off = diff_offset lvx lv in
          let f_fold_lset lvs acc =
            try
              let lvs = Lval.addOffsetLval off lvs in
              VSet.add (LLMap.find lvs x.lmap) acc
            with
              Not_found -> acc
          in
          LSet.fold
            f_fold_lset
            set_aliases
            acc
        else
          acc
      in
      let vset_res =
        LMap.fold
          f_fold_lmap
          map_predecessors
          VSet.empty
      in
      if VSet.is_empty vset_res
      then create_vertex_lval lv x
      else
        begin
          assert (VSet.cardinal vset_res = 1);
          let v_res = VSet.choose vset_res in
          (* vertex found, update the tables *)
          let new_lmap = LLMap.add lv v_res x.lmap in
          let new_vmap = VMap.add v_res (LSet.add lv (VMap.find v_res x.vmap)) x.vmap in
          v_res, {x with lmap = new_lmap; vmap = new_vmap}
        end
    end


(* TODO is there a better way to do it ? *)
let find_vertex lv x =
  let lv = Lval.from_lval lv in
  let v,x1 = find_or_create_vertex lv x in
  if x == x1
  (* if x has not been modified, then the vertex was found, not created *)
  then v
  else raise Not_found

let points_to (lv:Lval.t) (x:t): V.t list * t =
  let (v,x) = find_or_create_vertex lv x in
  G.succ x.graph v, x

let addr_of (lv:Lval.t) (x:t) : V.t list * t =
  let (v,x) = find_or_create_vertex lv x in
  G.pred x.graph v, x

let _remove_cst_vertex (v:V.t) (x:t) : t =
  Format.printf "Removing vertex %d@." v;
  assert (LSet.is_empty (VMap.find v x.vmap));
  {
    graph = G.remove_vertex x.graph v;
    pending = VMap.remove v x.pending;
    lmap = x.lmap;
    vmap = VMap.remove v x.vmap;
    cmpt = x.cmpt(* ;
                  * collapsed = x.collapsed *)
  }

(* remove a lval from a graph*)
let remove_lval (x:t)  (lv:Lval.t) :t =
  assert_invariants x;
  let new_x =
    try
      let v = LLMap.find lv x.lmap in
      let setv= VMap.find v x.vmap in
      let new_lmap = LLMap.remove lv x.lmap in
      let new_vmap = VMap.add v (LSet.remove lv setv) x.vmap in
      {x with lmap = new_lmap; vmap = new_vmap}
    with
      Not_found -> x
  in
  assert_invariants new_x; new_x



(* merge of two vertices; the first vertex carries both sets, the second is removed from the graph and from lmap and vmap; however, pending is NOT updated  *)
let merge x v1 v2 =
  if (V.equal v1 v2) || not (G.mem_vertex x.graph v1) || not (G.mem_vertex x.graph v2)
  then x
  else
    let set1 = find_lset v1 x in
    let set2 = find_lset v2 x in
    (* because of the offset, check if one of the *)

    let new_set = LSet.union set1 set2 in
    (* update lmap : every lval in v2 must now be associated with v1*)
    let new_lmap = LSet.fold (fun lv2 m -> LLMap.add lv2 v1 m) set2 x.lmap in
    (* update vmap *)
    let new_vmap = VMap.add v1 new_set (VMap.remove v2 x.vmap) in
    (* update collapse *)
    (* let new_collapsed =
     *   if VSet.mem v2 x.collapsed
     *   then
     *     VSet.add v1 (VSet.remove v2 x.collapsed)
     *   else
     *     x.collapsed
     * in *)
    (* update the graph *)
    let f_fold_succ v_succ (g:G.t) : G.t =
      G.add_edge g v1 v_succ
    and f_fold_pred v_pred (g:G.t) : G.t =
      G.add_edge g v_pred v1
    in
    let g = x.graph in
    (* adds all new edges *)
    let g = G.fold_succ f_fold_succ g v2 g in
    let g = G.fold_pred f_fold_pred g v2 g in
    (* remove v2 *)
    let g =  G.remove_vertex g v2 in
    {graph = g; pending = x.pending; lmap = new_lmap ; vmap = new_vmap ; cmpt = x.cmpt (* ; collapsed = new_collapsed *)}


(* (\* merge all nodes of an array a to a[0] *\)
 * let collapse (lv:Lval.t) (x:t) : t =
 *   let v, x = find_or_create_vertex lv x in
 *   let lv0 = first_index lv in
 *   let v0, x = find_or_create_vertex lv0 x in
 *   let map_to_be_collapsed = LLMap.find_indexed_offsets lv x.lmap in
 *   (\* merge all nodes that are indexed with v0 *\)
 *   let f_fold _lvx vx acc =
 *     let acc = merge acc v0 vx in
 *     let p = VMap.add v0 (VSet.union (VMap.find v0 acc.pending) (VMap.find vx acc.pending)) acc.pending in
 *     let new_pending = VMap.remove vx p in
 *     {acc with pending = new_pending }
 *   in
 *   LMap.fold f_fold map_to_be_collapsed {x with collapsed = VSet.add v x.collapsed } *)


(* let collapse_node (v:V.t) (x:t) : t =
 *   let ls = try VMap.find v x.vmap with Not_found -> LSet.empty in
 *   LSet.fold
 *     (fun lv acc -> collapse lv acc)
 *     ls
 *     x *)

(* (\* has a side effect on list_arrays_to_be_collapsed *\)
 * let collapse_graph (x:t) : t =
 *   let res =
 *     List.fold_left
 *       (fun acc lv ->
 *          let v,acc = find_or_create_vertex lv acc in
 *          collapse_node v acc)
 *       x
 *       !list_arrays_to_be_collapsed
 *   in
 *   list_arrays_to_be_collapsed := []; res *)



(* let normalize_lval (lv:Lval.t) (x:t) : lval * t =
 *   let new_lv = normalize_lval x lv in
 *   let new_x =
 *     if !list_arrays_to_be_collapsed != []
 *     then
 *       collapse_graph x
 *     else
 *       x
 *   in (\* now, list_arrays_to_be_collapsed = [] *\)
 *   new_lv, new_x *)

let normalize_lval lv x = (Lval.from_lval lv,x)

(** .dot printing functions*)
let find_vertex_name_ref = Extlib.mk_fun "find_vertex_name"

let lset_to_string (s: LSet.t) : string =
  let fmt = Format.str_formatter in
  Format.fprintf fmt "\"%a\"" LSet.pretty s;
  Format.flush_str_formatter ()

module Dot = Graphviz.Dot(struct
    include G
    let edge_attributes _ = []
    let default_edge_attributes _ = []
    let get_subgraph _ = None
    let vertex_attributes _ = [`Shape `Box]
    let vertex_name (v:V.t) =
      let lset = !find_vertex_name_ref v in
      let v_name = lset_to_string lset in
      (* Format.printf "Vertex %d set %s@." v v_name; *)
      v_name
    let default_vertex_attributes _ = []
    let graph_attributes _ = []
  end)

let print_dot filename (a:t) =
  let file = open_out filename in
  find_vertex_name_ref :=
    (fun v -> find_lset v a
    );
  Dot.output_graph file a.graph;
  close_out file



(** functions for steensgard's algorithm *)


(* functions join and unify-pointer of steensgaard's paper *)
let rec join (x:t) (v1:V.t) (v2:V.t) : t =
  if (V.equal v1 v2) || not (G.mem_vertex x.graph v1 && G.mem_vertex x.graph v2)
  then
    x
  else
    let pt1 = G.succ x.graph v1 in (* TODO ask frama-c type instead of looking in the graph *)
    let pt2 = G.succ x.graph v2 in
    let x = merge x v1 v2 in
    assert (not (G.mem_vertex x.graph v2));
    match (pt1, pt2) with
      [],[] ->
      (* update pending *)
      let p = VMap.add v1 (VSet.union (VMap.find v1 x.pending) (VMap.find v2 x.pending)) x.pending in
      let new_pending = VMap.remove v2 p in
      {x with pending = new_pending }
    | [], _ ->
      (* join pending v1 *)
      let x =
        VSet.fold
          (fun v x -> join x v v1)
          (try VMap.find v1 x.pending with Not_found -> VSet.empty )
          x
          (* update pending *)
      in let new_pending = VMap.add v1 VSet.empty (VMap.remove v2 x.pending) in
      {x with pending = new_pending }
    | _, [] ->
      (* join pending v2 *)
      let x =
        VSet.fold
          (fun v x -> join x v v1)
          (try VMap.find v2 x.pending with Not_found -> VSet.empty )
          x
      in let new_pending = VMap.add v1 VSet.empty (VMap.remove v2 x.pending) in
      {x with pending = new_pending }
    | _, _ ->
      (* assert pending(v1) = empty and assert pending (v2) =empty *)
      let new_pending = (VMap.remove v2 x.pending) in
      (* join the succesors *)
      unify {x with pending=new_pending} pt1 pt2

(* [unify x l1 l2] folds [join x v1 v2] for all [v1] in [l1] and all [v2] in [l2] *)
and unify (x:t) (l1:V.t list) (l2:V.t list) =
  match l1 with
    [] -> x
  | v1::qq ->
    let x = unify2 x v1 l2 in
    unify x qq l2

(* [unify2 x v1 l2] folds [join x v1 v2] for all [v2] in [l2] *)
and unify2 (x:t) (v1:V.t) (l2:V.t list) =
  match l2 with
    [] -> x
  | v2::qq ->
    let x = join x v1 v2 in
    unify2 x v1 qq

(* since the recursive version of join, unify, unify2 and merge may break the invariants *)
let join (x:t) (v1:V.t) (v2:V.t) : t =
  (* Options.feedback ~level:2 "GRAPH BEFORE JOIN(v_%d,v_%d) @.%a@." v1 v2 (pretty ~debug:true) x; *)
  assert_invariants x;
  let res = join x v1 v2 in
  assert_invariants res; res

let cjoin  (x:t) (v1:V.t) (v2:V.t) : t =
  assert_invariants x;
  let pt2 =  G.succ x.graph v2 in
  if pt2 = []
  then
    let old_set = try VMap.find v1 x.pending with Not_found -> VSet.empty in
    let new_pending = VMap.add v1 (VSet.add v2 old_set) x.pending in
    {x with pending=new_pending}
  else
    join x v1 v2

(* in Steensgard's paper, this is written settype(v1,ref(v2,bot)) *)
let set_type (x:t) (v1:V.t) (v2:V.t) : t =
  assert_invariants x;
  (* if v1 points to another node, suppress current outgoing edge (and the node if it is a constant node) *)
  let g =
    match G.succ x.graph v1 with
      [] -> x.graph
    | [v2] ->
      (* if v2 is a constant node supress it directly *)
      if LSet.is_empty (VMap.find v2 x.vmap)
      then G.remove_vertex x.graph v2
      else G.remove_edge x.graph v1 v2
    | _ -> Options.fatal "two many outgoing edges in set_type"
  in
  let new_g = G.add_edge g v1 v2 in
  VSet.fold (fun vx x -> join x v1 vx) (try VMap.find v1 x.pending with Not_found -> VSet.empty) {x with graph = new_g}


(* assignment x = y *)
let assignment_x_y (a:t) (x:lval) (y:lval) : t =
  assert_invariants a;
  let x,a = normalize_lval x a in
  let y,a = normalize_lval y a in
  let (v1,a) = find_or_create_vertex x a in
  let (v2,a) = find_or_create_vertex y a in
  let new_a = cjoin a v1 v2 in
  assert_invariants new_a ; new_a


(* assignment x = &y *)
let assignment_x_addr_y (a:t) (x:lval) (y:lval) : t =
  assert_invariants a;
  let x,a = normalize_lval x a in
  let y,a = normalize_lval y a in
  let v1, a = find_or_create_vertex x a in
  let list_v2, a = addr_of y a in
  let new_a =
    if list_v2 = []
    then
      let v2, a = find_or_create_vertex y a in
      set_type a v1 v2
    else
      List.fold_left
        (fun a_acc v2 -> join a_acc v1 v2)
        a
        list_v2
  in
  assert_invariants new_a ; new_a


(* assignment x = *y *)
let assignment_x_ptr_y (a:t) (x:lval) (y:lval) : t =
  assert_invariants a;
  let x,a = normalize_lval x a in
  let y,a = normalize_lval y a in
  let v1, a = find_or_create_vertex x a in
  let list_v2, a = points_to y a in
  let new_a =
    match list_v2 with
      [] -> let v2,a = find_or_create_vertex y a in set_type a v2 v1
    | [v2] -> cjoin a v1 v2
    | _ ->  Options.fatal "assignment_x_ptr_y not implemented"
  in
  assert_invariants new_a ; new_a

(* assignment x = allocate(y) *)
let assignment_x_allocate_y (a:t) (x:lval) : t =
  assert_invariants a;
  let x,a = normalize_lval x a in
  let (v1,a) = find_or_create_vertex x a in
  let (v2,a) = create_cst_vertex a in
  let new_a = set_type a v1 v2 in
  assert_invariants new_a ; new_a

(* assignment *x = y *)
let assignment_ptr_x_y (a:t) (x:lval) (y:lval) : t =
  assert_invariants a;
  let x,a = normalize_lval x a in
  let y,a = normalize_lval y a in
  let v2, a = find_or_create_vertex y a in
  let list_v1, a = points_to x a in
  let new_a =
    match list_v1 with
      [] ->  let v1,a = find_or_create_vertex x a in set_type a v1 v2
    |  [v1] -> cjoin a v1 v2
    | _ ->  Options.fatal "assignment_ptr_x_y not implemented"
  in
  assert_invariants new_a ; new_a


(* assignment *x = cst *)
let assignment_ptr_x_cst (a:t) (x:lval) : t =
  assert_invariants a;
  let x,a = normalize_lval x a in
  (* Format.printf "DEBUG (assignment_ptr_x_cst) on lval %a and state:@. %a @." Lval.pretty x print_debug a; *)
  let v2, a = create_cst_vertex a in
  let (list_v1, a) : V.t list * t = points_to x a in
  let new_a =
    match list_v1 with
      [] ->  let v1,a = find_or_create_vertex x a in set_type a v1 v2
    | _ -> let f_fold (acc:t) (v1:V.t) : t = cjoin acc v1 v2
      in List.fold_left f_fold a list_v1
  in
  assert_invariants new_a ; new_a

exception Not_included

let is_included (a1:t) (a2:t) =
  (* tests if a1 is included in a2, at least as the nodes with lval *)
  assert_invariants a1;
  assert_invariants a2;
  (* Format.printf "DEBUG testing equal @.%a@. AND à.%a@. END DEBUG@." (pretty ~debug:true) a1 (pretty ~debug:true) a2; *)
  try
    let iter_lmap (lv:Lval.t) (v1:V.t): unit =
      let v2 : V.t = try LLMap.find lv a2.lmap with Not_found -> raise Not_included in
      match G.succ a1.graph v1, G.succ a2.graph v2 with
        [], _ -> ()
      | [_], [] -> raise Not_included
      | [v1p], [v2p] ->
        if LSet.subset (VMap.find v1p a1.vmap) (VMap.find v2p a2.vmap)
        then
          ()
        else
          raise Not_included
      | _ -> Options.fatal "this should not hapen (invariant broken)"
    in
    LLMap.iter iter_lmap a1.lmap; true
  with
    Not_included -> false

(* let equal (a1:t) (a2:t) =
 *   assert_invariants a1;
 *   assert_invariants a2;
 *   Format.printf "DEBUG testing equal @.%a@. AND à.%a@. END DEBUG@." (pretty ~debug:true) a1 (pretty ~debug:true) a2;
 *   try
 *     let card = LLMap.cardinal a1.lmap in
 *     if (card = LLMap.cardinal a2.lmap)
 *     && G.nb_vertex a1.graph = G.nb_vertex a2.graph
 *     && G.nb_edges a1.graph = G.nb_edges a2.graph
 *     (\* the invariants assure that if the nb of vertex is equal, then
 *        the size of pending and vmap are also equal. nb counters may be
 *        different, it doesn't matter *\)
 *     then
 *       begin
 *         (\* builds the isomorphism between vertex numbers as an
 *              Hastable Int.t -> Int.t *\)
 *           let iso : (V.t, V.t) Hashtbl.t = Hashtbl.create card in
 *           LLMap.iter
 *             (fun lv v1 ->
 *                let v2 : V.t = try LLMap.find lv a2.lmap with Not_found -> raise Not_equal in
 *                try if not (V.equal (Hashtbl.find iso v1) v2) then raise Not_equal
 *                with Not_found ->
 *                  Hashtbl.add iso v1 v2
 *             )
 *             a1.lmap;
 *           (\* now, iso is the isomorphism between vertex numbers. NB constant vertices are NOT in the map *\)
 *           (\* we check, for every vertex of a1.graph, that its successors and predecessors are isomorphic *\)
 *           let check_vertex (v1:V.t) : unit =
 *             if not (LSet.is_empty (VMap.find v1 a1.vmap))
 *             then (\* v1 is not a constant node, so it is an entry in iso *\)
 *               let v2 =
 *                 try
 *                   Hashtbl.find iso v1
 *                 with
 *                   Not_found -> Options.fatal "this should not happen (broken invariant or hashtable iso)"
 *               in
 *               begin
 *                 (\* we only need to check the successors; the predecessor will be checked because we iterate on all vertex *\)
 *                 match G.succ a1.graph v1 with
 *                   [] -> (\* if v1 has no successor, then so must have v2 *\)
 *                   if List.length (G.succ a2.graph v2) > 0 then raise Not_equal
 *
 *                 | [succ_v1] ->
 *                   begin
 *                     if LSet.is_empty (VMap.find succ_v1 a1.vmap)
 *                     then
 *                       (\* veryfy that v2 has a successor that is also a constant vertex*\)
 *                       match G.succ a2.graph v2 with
 *                         [succ_v2] when LSet.is_empty (VMap.find succ_v2 a2.vmap) -> ()
 *                       | _ -> raise Not_equal
 *                     else
 *                       let succ_v2 : V.t =
 *                         try
 *                           Hashtbl.find iso succ_v1
 *                         with
 *                           Not_found -> Options.fatal "this should not happen (broken invariant or hashtable iso)"
 *                       in
 *                       (\* simply check for an edge between v2 and succ v_2 *\)
 *                       if not (G.mem_edge a2.graph v2 succ_v2) then raise Not_equal
 *                   end
 *                 | _ -> Options.fatal "this should not happen (broken invariant)"
 *               end
 *             else (\* if it is a constant node, nothing to do *\)
 *               ()
 *           in
 *           G.iter_vertex check_vertex a1.graph; true
 *         end
 *     else
 *       (\* if the cardinal is different, there cannot be an isomorphism *\)
 *       false
 *   with
 *     Not_equal -> false *)


module VPairs =
struct
  type t = V.t * V.t
  let compare (x0,y0) (x1,y1) =
    match V.compare x0 x1 with
      0 -> V.compare y0 y1
    | c -> c
end

module V2Set = Set.Make(VPairs)



(* rename all vertex re-enumerate all vertex of [x] from 0 to nb_vertex -1 *)
let rename_all_vertex (x:t) : t =
  assert_invariants x;
  let new_cmpt = ref 0 in
  let tbl_rename = Hashtbl.create (G.nb_vertex x.graph) in
  (* fill the table *)
  G.iter_vertex  (fun v -> Hashtbl.add tbl_rename v !new_cmpt ; incr new_cmpt) x.graph;
  let r v =
    try
      Hashtbl.find tbl_rename v
    with
      Not_found -> Format.printf "DEBUG FAILED RENAME (%d not found) @.%a@." v (pretty ~debug:true) x; raise Not_found
  in
  let renamed_graph =
    (* rename the graph and write the table *)
    G.map_vertex
      r
      x.graph
  in

  let renamed_pending =
    VMap.fold
      (fun v vs acc ->
         if G.mem_vertex x.graph v
         then VMap.add (r v) vs acc
         (* if it is not a vertex, then it is an aritfact of the map *)
         else acc
      )
      x.pending
      VMap.empty
  in
  let renamed_lmap =
    LLMap.map
      r
      x.lmap
  in
  let renamed_vmap =
    VMap.fold
      (fun v ls acc ->
         if G.mem_vertex x.graph v
         then
           VMap.add (r v) ls acc
         else
           acc
      )
      x.vmap
      VMap.empty
  in
  let new_x =
    {graph = renamed_graph; pending = renamed_pending ; lmap = renamed_lmap ; vmap = renamed_vmap ; cmpt = !new_cmpt (* ; collapsed = x.collapsed *)}
  in
  assert_invariants new_x; new_x

let union  (a1:t) (a2:t) :t =
  (* naive algorithm :
     1 rename any vertex in a2 (by adding a1.cmpt) to avoid any confusion between vertex of the tw graphs
     2 merge the graph and the vmap and pending (by doing union of sets)
     3 for any lval [lv] that are has an entry in both a1.lmap and a2.lmap, merge the two vertex a1.lmap[lv]
       and a2.lmap[lv]

     I am not confident about this function, there are too many potential bugs and inefficiencies
  *)
  assert_invariants a1;
  assert_invariants a2;

  Format.printf "BEGIN DEBUG UNION@.";
  Format.printf "First graph:@.%a@." print_debug a1;
  Format.printf "Second graph:@.%a@." print_debug a2;
  Format.printf "END DEBUG UNION@.";
  let f_v2 x = x + a1.cmpt in
  (* we build the new graph, starting from a1.graph *)
  let g = a1.graph in
  (* add all vertex of a2 in g *)
  let g =
    G.fold_vertex
      (fun v2 g -> G.add_vertex g (f_v2 v2))
      a2.graph
      g
  in
  (* add all edges of a2 in g *)
  let new_graph =
    G.fold_edges
      (fun v2a v2b g -> G.add_edge g (f_v2 v2a) (f_v2 v2b))
      a2.graph
      g
  in
  let new_pending =
    VMap.fold
      (fun v2 p2 m -> VMap.add (f_v2 v2) p2 m)
      a2.pending
      a1.pending
  in
  let new_vmap =
    VMap.fold
      (fun v2 lset2 m -> VMap.add (f_v2 v2) lset2 m)
      a2.vmap
      a1.vmap
  in
  (* let new_collapsed =
   *   VSet.union a1.collapsed a2.collapsed
   * in *)
  let rec find_all_successors (set_res: V2Set.t) (v1: V.t) (v2:V.t) (g:G.t) =
    (* NB this function assumes there is no strongly connected components in the graph !!! *)
    match (G.succ g v1, G.succ g v2) with
      ([],_) | (_,[]) -> set_res
    | ([succ_v1], [succ_v2]) -> find_all_successors (V2Set.add (v1,(f_v2 v2)) set_res) succ_v1 succ_v2 g
    | _ -> Options.fatal "Broken invariant: at most 1 successor"

  in
  (* s_acc = set of couples that should be merged in step 3 *)
  let set_to_be_merged, new_lmap =
    LLMap.fold
      (fun lv v2 (s_acc, m_acc) ->
         (* if lv has an entry in a1.lmap, then add the two vertex to be merged *)
         try
           let v1 = LLMap.find lv a1.lmap in
           let set_with_successors = find_all_successors (V2Set.add (v1,(f_v2 v2)) s_acc) v1 (f_v2 v2) new_graph in
           (set_with_successors, m_acc)
         (* WARNING : potential bug here: the invariant of lmap is broken
            since lv shall be mapped to both v1 and (f_v2 v2); the merge
            that are done in step 3 shall restore the invariant*)
         with
         (* if not, simply add the lval -> f_v2 v2 in m_acc *)
           Not_found -> (s_acc, LLMap.add lv (f_v2 v2) m_acc)
      )
      a2.lmap
      (V2Set.empty, a1.lmap)
  in
  let new_a = { graph = new_graph ; pending = new_pending ; lmap = new_lmap ; vmap = new_vmap ; cmpt = a1.cmpt + a2.cmpt (* ; collapsed = new_collapsed  *)} in

  (* step 3 *)
  let new_a =
    V2Set.fold
      (fun (v1, v2) a ->
         let new_a = merge a v1 v2 in
         let new_vset  =
           let p1=  try  (VMap.find v1 new_a.pending) with Not_found -> VSet.empty in
           let p2=  try  (VMap.find v2 new_a.pending) with Not_found -> VSet.empty in
           VSet.union p1 p2
         in
         (* warning: exploits the fact that v1 is preserved in the merge operation *)
         let new_pending = VMap.add v1 new_vset (VMap.remove v2 new_a.pending) in
         { new_a with pending = new_pending }
      )
      set_to_be_merged
      new_a
  in
  (* (\* there may be some inconsistancies with constant nodes, so we clean up *\)
   * let clean_up_constant_successors (v:V.t) (res_a:t) : t =
   *   let l_succ = G.succ new_a.graph v in
   *   if l_succ = []
   *   then res_a (\* nothing to do *\)
   *   else
   *     (\* find the only successor that is not a constant node *\)
   *     let true_succ =
   *       List.fold_left
   *         (fun res v ->
   *            if LSet.is_empty (VMap.find v res_a.vmap)
   *            then res
   *            else v)
   *         (List.hd l_succ)
   *         l_succ
   *     in
   *     (\* eliminate all nodes that is not the true successor *\)
   *     List.fold_left
   *       (fun res_a v -> if V.equal v true_succ then res_a else remove_cst_vertex v res_a)
   *       res_a
   *       l_succ
   * in
   * let new_a =
   *   G.fold_vertex
   *     clean_up_constant_successors
   *     new_a.graph
   *     new_a
   * in *)
  let new_a =
    (* if new_a.cmpt > 2 * (G.nb_vertex new_a.graph)
     * then *)
    rename_all_vertex new_a
    (* else
     *   new_a *)
  in
  assert_invariants new_a;
  new_a

let empty :t =
  {graph = G.empty; pending = VMap.empty ; lmap = LLMap.empty; vmap = VMap.empty; cmpt = 0(* ; collapsed = VSet.empty *)}


(* let _make_top (x:t) : t =
 *   if x.graph = G.empty
 *   then x
 *   else
 *     let g = G.add_edge (G.add_vertex G.empty 0) 0 0 in
 *     (\* collect all lval of the initial set *\)
 *     let set_lv = ref LSet.empty in
 *     let lmap =
 *       LLMap.mapi
 *         (fun lv _ -> set_lv := LSet.add lv !set_lv ; 0)
 *         x.lmap
 *     in
 *     let vmap =
 *       VMap.add 0 !set_lv VMap.empty
 *     in
 *     let p = VMap.add 0 VSet.empty VMap.empty in
 *     {graph = g ; pending = p ; lmap = lmap ; vmap = vmap ; cmpt = 1(\* ; collapsed = x.collapsed *\)} *)

(** a type for summaries of functions *)
type summary =
  {
    state : t option;
    formals: Lval.t list;
    locals: Lval.t list;
    return : exp option
  }

let make_summary (s: t option) (kf: kernel_function) =
  let exp_return : exp option =
    if Kernel_function.has_definition kf then
      let return_stmt = Kernel_function.find_return kf in
      match return_stmt.skind with
        Return (e, _) -> e
      | _ -> Options.fatal "this should not happen"
    else
      None
  in
  {
    state = s;
    formals = List.map (fun v -> BLval (Var v,NoOffset)) (Kernel_function.get_formals kf);
    locals = List.map (fun v -> BLval (Var v,NoOffset))  (Kernel_function.get_locals kf);
    return = exp_return
  }


let pretty_summary ?(debug=false) ?(function_name="") fmt s =
  let print_list_lval fmt (l: Lval.t list) =
    List.iter (fun x -> Format.fprintf fmt "%a " Lval.pretty x) l
  in
  let print_option pp fmt x =
    match x with
    | Some x -> pp fmt x
    | None -> Format.fprintf fmt "<None>"
  in
  Format.fprintf fmt "@[<hov 2>Summary of function %s: @." function_name;
  Format.fprintf fmt "formals: %a locals : %a return expression: %a @.State: @[<hov 2>%a@] " print_list_lval s.formals print_list_lval s.locals (print_option Exp.pretty) s.return (print_option (pretty ~debug)) s.state;
  Format.fprintf fmt "@]@."


let call (state:t) (res:lval option) (args:exp list) (summary:summary) :t =
  assert_invariants state;
  let formals = summary.formals in
  let sum_state =
    match summary.state with
      None -> Options.fatal "BUG this should not happen"
    | Some s -> s
  in
  assert (List.length args = List.length formals);
  (* check that formal variables do no appear in state *)
  List.iter
    (fun lv -> assert (not (LLMap.mem lv state.lmap)))
    formals;
  (* union of the two graphs *)
  let new_state = union state sum_state in
  (* union of formal parameters *)
  let new_state =
    List.fold_left2
      (fun acc param formal ->
         begin
           let arg = Lval.from_exp param in
           match  formal, arg  with
             ( BLval(Var v1, o1), BLval (Var v2,o2)) ->
             (* case x = y *)
             assignment_x_y acc (Var v1, o1) (Var v2, o2)
           | ( BLval(Var _, _), BNone) -> acc
           (* constant assignments : do nothing, but maybe check the type of the assigned variable ? *)
           | ( BLval(Var v1, o1), BAddrOf lv2) ->
             (* case x = &y *)
             assignment_x_addr_y acc (Var v1, o1) lv2
           | ( BLval(Var v1, o1), BLval (Mem e2, _)) ->
             (* case x  = *y *)
             begin
               match e2.enode with
                 Lval lv2 -> assignment_x_ptr_y acc (Var v1, o1) lv2
               |  _ -> (Options.feedback "In a function call, parameter (@[%a@] <- @[%a@]) is ignored)" Lval.pretty formal Exp.pretty param; acc)
             end
           | _ -> (Options.feedback "DEBUG: call function - formal variable not as we expected@."; acc)
         end
      )
      new_state
      args
      formals
  in
  (* set the result *)
  let new_state =
    match (res, summary.return) with
      None, _  -> new_state
    | (Some res, Some exp_res) ->
      begin
        let v_res,new_state  = find_or_create_vertex (Lval.from_lval res) new_state in
        match Lval.from_exp exp_res with
          BLval lval_exp_res ->
          begin
            try
              let v_exp_res =  LLMap.find (BLval lval_exp_res) new_state.lmap in
              join new_state v_res v_exp_res
            with
              Not_found -> (Options.feedback ~level:2 "result expression %a does not appear in the summary of the called function (ressult not assigned)" Lval.pretty (BLval lval_exp_res); new_state)
          end
        | _ -> new_state
      end
    | (Some _, None) -> (Options.warning "a function with no return is employed in an assignment" ; new_state)
  in
  (* erase all formals and all locals from the tables/graphs *)
  let new_state =
    List.fold_left
      remove_lval
      new_state
      (summary.formals@summary.locals)
  in
  assert_invariants new_state;
  new_state
