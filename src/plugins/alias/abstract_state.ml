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
  G.iter_vertex (fun v -> Format.fprintf fmt "id=%d LSet=%a@." v LSet.pp_debug (find_lset v x)) x.graph;
  Format.fprintf fmt "@]@.@[<hov 2>List of edges: @.";
  G.iter_edges (fun v1 v2 -> Format.fprintf fmt "%d → %d@." v1 v2) x.graph;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "@[<hov 2>Pending: @.";
  VMap.iter (fun v vs -> Format.fprintf fmt "id=%d pending=%a@." v VSet.pretty vs) x.pending;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "@[<hov 2>LMap: @.";
  LLMap.pretty fmt x.lmap;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "@[<hov 2>VMap: @.";
  VMap.iter (fun v ls -> Format.fprintf fmt "id=%d → lset=%a@." v LSet.pp_debug ls) x.vmap;
  Format.fprintf fmt "@]@.";
  Format.fprintf fmt "cmpt: %d@." x.cmpt

let print_graph fmt (x:t) =
  let print_edge v1 v2 =
    LSet.pretty fmt @@ VMap.find v1 x.vmap;
    Format.fprintf fmt " → ";
    LSet.pretty fmt @@ VMap.find v2 x.vmap;
    Format.fprintf fmt "@.";
  in
  G.iter_edges print_edge x.graph

let print_aliases fmt (x:t) =
  let print_set ?(first = true) pretty fmt s =
    let first = ref first in
    let print_element e =
      if !first then first := false else Format.fprintf fmt "%s" "; ";
      Format.fprintf fmt "%a" pretty e in
    LSet.iter print_element s
  in
  let print_lv_and_pred lv pred =
    Format.fprintf fmt "{%a%a} are aliased@."
      (print_set Lval.pretty) lv
      (print_set ~first:false (fun fmt -> Format.fprintf fmt "*%a" Lval.pretty)) pred
  in
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
            print_lv_and_pred set_lv !set_pred
        end
      | _ -> Options.fatal "this should not happen"
  in
  Format.fprintf fmt "@[<hov 2>";
  VMap.iter iter_vmap x.vmap;
  Format.fprintf fmt "@]@."

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
  let assert_vmap (v:V.t) (ls:LSet.t) =
    assert (LSet.fold (fun lv acc -> acc && V.equal (LLMap.find lv x.lmap) v) ls true)
  in
  VMap.iter assert_vmap x.vmap

(* for debuging, remove this function before last deliverable *)
let assert_invariants x =
  try assert_invariants x
  with
    Assert_failure f ->
    Options.error "failed invariants@.%a@." print_debug x;
    raise (Assert_failure f)

let pretty ?(debug=false) fmt (x:t) =
  if debug then
    try
      assert_invariants x;
      print_graph fmt x
    with Assert_failure _ -> print_debug fmt x
  else
    print_aliases fmt x

let assert_state_transformation (x:t) (f: t -> t) : t =
  assert_invariants x;
  let result = f x in
  assert_invariants result;
  result

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
    cmpt = x.cmpt+1
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
  Options.debug "decompose_lval %a : [@[<hov 2>" Lval.pp_debug lv1;
  List.iter (fun (x, o) -> Options.debug " (%a,%a) " Lval.pp_debug x Offset.pretty o) list_of_lval_to_be_searched;
  Options.debug "@]]@.";
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
  let set_of_aliases : LSet.t = find_all_aliases lv x in
  (* add all these aliases *)
  Options.debug "all_aliases of %a : %a @." Lval.pp_debug lv LSet.pp_debug set_of_aliases;
  let new_lmap =
    LSet.fold
      (fun lv acc -> assert (not (LLMap.mem lv x.lmap)); LLMap.add lv new_v acc)
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
      cmpt = x.cmpt+1
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
  assert (not (LLMap.mem blv x.lmap));
  Options.debug "creating a vertex for %a@." Lval.pp_debug blv;
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
            (* then creates a vertex for bvl ONLY IF there is no successor *)
            begin
              match G.succ x.graph v1 with
                [] ->
                let v2, x = create_vertex_simple blv x in
                (* finally add a points-to edge between v1 and v2 *)
                let new_graph = G.add_edge x.graph v1 v2 in
                v2, {x with graph = new_graph }
              | [succ_v1] ->
                (* if there is a successor, update lmap and vmap to add blv to that successor's set *)
                let new_lmap = LLMap.add blv succ_v1 x.lmap in
                let new_vmap = VMap.add succ_v1 (LSet.add blv (VMap.find succ_v1 x.vmap)) x.vmap in
                succ_v1, {x with lmap = new_lmap ; vmap = new_vmap }
              | _ -> Options.fatal " Invariant violated : more than 1 successor"
            end
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
        Options.debug "looking for aliases of %a in set %a@." Lval.pp_debug lv LSet.pp_debug set_aliases;
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
      (* set of all existing aliases *)
      let vset_res =
        LMap.fold
          f_fold_lmap
          map_predecessors
          VSet.empty
      in
      Options.debug "found aliases of %a : %a@." Lval.pp_debug lv VSet.pretty vset_res;
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
  Options.debug "Removing vertex %d@." v;
  assert (LSet.is_empty (VMap.find v x.vmap));
  {
    graph = G.remove_vertex x.graph v;
    pending = VMap.remove v x.pending;
    lmap = x.lmap;
    vmap = VMap.remove v x.vmap;
    cmpt = x.cmpt
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
    {graph = g; pending = x.pending; lmap = new_lmap ; vmap = new_vmap ; cmpt = x.cmpt}

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
let rec join_without_check (x:t) (v1:V.t) (v2:V.t) : t =
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
          (fun v x -> join_without_check x v v1)
          (try VMap.find v1 x.pending with Not_found -> VSet.empty )
          x
          (* update pending *)
      in let new_pending = VMap.add v1 VSet.empty (VMap.remove v2 x.pending) in
      {x with pending = new_pending }
    | _, [] ->
      (* join pending v2 *)
      let x =
        VSet.fold
          (fun v x -> join_without_check x v v1)
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
    let x = join_without_check x v1 v2 in
    unify2 x v1 qq

(* since the recursive version of join, unify, unify2 and merge may break the invariants *)
let join (x:t) (v1:V.t) (v2:V.t) : t =
  Options.debug ~level:2 "GRAPH BEFORE JOIN(v_%d,v_%d) @.%a@." v1 v2 (pretty ~debug:true) x;
  assert_invariants x;
  let res = join_without_check x v1 v2 in
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
    | _ -> Options.fatal "too many outgoing edges in set_type"
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
  Options.debug "(assignment_ptr_x_cst) on lval %a and state:@. %a @." Lval.pretty x print_debug a;
  let v2, a = create_cst_vertex a in
  let (list_v1, a) : V.t list * t = points_to x a in
  let new_a =
    match list_v1 with
      [] ->  let v1,a = find_or_create_vertex x a in set_type a v1 v2
    | [v1] ->  cjoin a v1 v2
    | _ -> Options.fatal "invariant broken "
  in
  assert_invariants new_a ; new_a

exception Not_included

let is_included (a1:t) (a2:t) =
  (* tests if a1 is included in a2, at least as the nodes with lval *)
  assert_invariants a1;
  assert_invariants a2;
  Options.debug "testing equal @.%a@. AND à.%a@." (pretty ~debug:true) a1 (pretty ~debug:true) a2;
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

module VPairs =
struct
  type t = V.t * V.t
  let compare (x0,y0) (x1,y1) =
    match V.compare x0 x1 with
      0 -> V.compare y0 y1
    | c -> c
end

module V2Set = Set.Make(VPairs)

(* add an int to all vertex values *)
let shift (a : t) (offset : int) : t =
  assert_state_transformation a @@ fun a ->
  (* maybe if offset < #vertices there will be a problem? *)
  let offset = max offset @@ G.nb_vertex a.graph in
  let shift x = x + offset in
  let shift_vmap shift_elem vmap =
    VMap.of_seq @@ Stdlib.Seq.map shift_elem @@ VMap.to_seq vmap
  in
  let {graph; pending; lmap; vmap; cmpt} = a in
  let pending' =
    let shift_elem (key, set) = (shift key, VSet.map shift set) in
    shift_vmap shift_elem pending
  in
  {graph = G.map_vertex shift graph;
   pending = pending';
   lmap = LLMap.map shift lmap;
   vmap = shift_vmap (fun (key, l) -> (shift key, l)) vmap;
   cmpt = shift cmpt}

let lmap_intersect l r =
  let find_in_l lval vr acc =
    try (LLMap.find lval l, vr) :: acc with Not_found -> acc
  in
  LLMap.fold find_in_l r []

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

  Options.debug "Union: First graph:@.%a@." print_graph a1;
  Options.debug "Union: Second graph:@.%a@." print_graph a2;
  (* ensure that a1 and a2 no longer share any vertex indices *)
  let a2 = shift a2 a1.cmpt in
  let new_graph =
    G.fold_vertex
      (fun v2 g -> G.add_vertex g v2)
      a2.graph
      a1.graph
  in
  let new_graph =
    G.fold_edges
      (fun v2a v2b g -> G.add_edge g v2a v2b)
      a2.graph
      new_graph
  in
  let new_pending = VMap.fold VMap.add a2.pending a1.pending in
  let new_vmap =
    VMap.fold
      (fun v2 lset2 m -> VMap.add v2 lset2 m)
      a2.vmap
      a1.vmap
  in
  let new_lmap =
    LLMap.fold
      (fun lv v2 m_acc -> LLMap.add lv v2 m_acc)
      a2.lmap
      a1.lmap
  in
  let to_be_joined = lmap_intersect a1.lmap a2.lmap in
  let new_a = { graph = new_graph ; pending = new_pending ; lmap = new_lmap ; vmap = new_vmap ; cmpt = max a1.cmpt a2.cmpt} in
  let new_a = List.fold_left (fun s (l,r) -> join_without_check s l r) new_a to_be_joined in
  Options.debug "Union: Result graph:@.%a@." print_graph new_a;
  assert_invariants new_a;
  new_a

let empty :t =
  {graph = G.empty; pending = VMap.empty ; lmap = LLMap.empty; vmap = VMap.empty; cmpt = 0}

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
           | _ -> (Options.debug "call function - formal variable not as we expected@."; acc)
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
