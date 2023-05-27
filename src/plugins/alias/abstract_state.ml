(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Graph

open Cil_types

open Cil_datatype

open Simplified

module VSet = Datatype.Int.Set
module VMap = Datatype.Int.Map

module Lval = Simplified.Lval

module LSet = Simplified.Simplified_lset
module LMap = Simplified.Simplified_lmap

module G = Persistent.Digraph.ConcreteBidirectional(Datatype.Int)

module V = G.V

type slval = Simplified.simplified_lval

let blval = function
  | BAddrOf _ -> Options.fatal "unexpected"
  | BLval lval -> lval

(* like LMap, but organized with offset and specialized functions *)
module LLMap =
struct
  module OMap = Offset.Map
  (* each t is a map (lhost,NoOffset) -> offset -> V.t *)
  type t = (V.t OMap.t) LMap.t

  let empty : t = LMap.empty

  let mem (lv : lval) (m:t) =
    let lv, off = Cil.removeOffsetLval lv in
    try
      OMap.mem off (LMap.find lv m)
    with
      Not_found -> false

  let find (lv : lval) (m:t) : V.t =
    let lv, off = Cil.removeOffsetLval lv in
    OMap.find off (LMap.find lv m)

  let add (lv : lval) (v:V.t) (m:t) :t  =
    let lv, off = Cil.removeOffsetLval lv in
    let mo = try LMap.find lv m with Not_found -> OMap.empty in
    LMap.add lv (OMap.add off v mo) m

  let iter f = LMap.iter @@ fun lv -> OMap.iter @@ fun o -> f @@ Cil.addOffsetLval o lv

  let map f = LMap.map @@ OMap.map f

  let pretty fmt =
    let is_first = ref true in
    LMap.iter (fun lv ->
        OMap.iter
          (fun o v -> let lv =  Cil.addOffsetLval o lv in
            if !is_first then is_first := false else Format.fprintf fmt "@;<3>";
            Format.fprintf fmt "@ @[%a:%d@]" Lval.pretty lv v))

  (* left-biased *)
  let union = LMap.union @@ fun _ l r -> Some (OMap.union (fun _ l _r -> Some l) l r)

  let intersect =
    let intersect_omap l r = match l, r with
      | Some l, Some r -> Some (l,r)
      | _ -> None
    in
    let intersect_lmap l r = match l, r with
      | Some l, Some r ->
        let omap = OMap.merge (fun _ -> intersect_omap) l r in
        if OMap.is_empty omap then None else Some omap
      | _ -> None
    in
    LMap.merge @@ fun _ -> intersect_lmap

  let to_seq m = LMap.fold (fun lv omap -> OMap.fold (fun o v s -> Seq.cons (lv,o,v) s) omap) m Seq.empty

  (* specialized functions *)
  let rec is_sub_offset o1 o2 =
    match (o1,o2) with
      NoOffset, _ -> true
    | Index (e1,o1), Index (e2,o2) when Cil_datatype.ExpStructEq.equal e1 e2 -> is_sub_offset o1 o2
    | Field (f1,o1), Field (f2,o2) when Fieldinfo.equal f1 f2 ->  is_sub_offset o1 o2
    | _ -> false

  (* finds all the lval lv1 apearing in [m] such as there exists an offset o1 and lv1 + o1 = lv *)
  let find_upper_offsets (lv : lval) (m:t) : V.t LMap.t =
    let lv, off = Cil.removeOffsetLval lv in
    let mo = try LMap.find lv m with Not_found -> OMap.empty in
    let f_filter o _v = is_sub_offset o off in
    let mo = OMap.filter f_filter mo in
    OMap.fold
      (fun o -> let lv = Cil.addOffsetLval o lv in LMap.add lv)
      mo
      LMap.empty

end

module type S =
sig
  (* see abstract_state.mli for coments *)
  type t
  val get_graph: t -> G.t
  val get_lval_set : G.V.t -> t -> LSet.t
  val pretty : ?debug:bool -> Format.formatter -> t -> unit
  val print_dot : string -> t -> unit
  val find_vertex : lval -> t -> G.V.t
  val find_aliases : lval -> t -> LSet.t
  val find_all_aliases : lval -> t -> LSet.t
  val points_to_set : lval -> t -> LSet.t
  val find_transitive_closure : lval -> t -> (G.V.t * LSet.t) list
  val is_included : t -> t -> bool
end

type t = {
  graph : G.t;
  lmap : LLMap.t ; (* lmap(lv) is a table [offset->v] where the vertex v corresponding to lval (lv+offset), in other words (lv+offset) is in label(v) *)
  vmap : LSet.t VMap.t ;(* reverse of lmap *)
}

let node_counter = ref 0
let fresh_node_id () =
  let id = !node_counter in
  node_counter := !node_counter + 1;
  id

(* find functions *)
let find_lset (v:V.t) (x:t) : LSet.t =
  try VMap.find v x.vmap
  with Not_found -> LSet.empty

let find_aliases (lv:lval) (x:t) =
  let lv = Lval.simplify lv in
  try
    let v = LLMap.find lv x.lmap in
    find_lset v x
  with Not_found -> LSet.empty

let rec get_points_to (v:V.t) (x:t) : LSet.t =
  assert (G.mem_vertex x.graph v);
  let set_predecessors =
    List.fold_left
      (fun acc v -> LSet.union acc (get_points_to v x))
      LSet.empty
      (G.pred x.graph v)
  in
  LSet.union
    (find_lset v x)
    (LSet.map Lval.points_to set_predecessors)

let aliases_of_vertex (v:V.t) (x:t) : LSet.t =
  assert (G.mem_vertex x.graph v);
  let list_pred = G.pred x.graph v in
  List.fold_left
    (fun acc v -> LSet.union acc (get_points_to v x))
    LSet.empty
    list_pred

let succ_of_lval (lv:lval) (x:t) : int option =
  let lv = Lval.simplify lv in
  try begin
    let v = LLMap.find lv x.lmap in
    match G.succ x.graph v with
    | [] -> None
    | [succ_v] -> Some succ_v
    | _ -> Options.fatal "invariant violated (more than 1 successor)"
  end with Not_found -> None

let find_all_aliases (lv:lval) (x:t) : LSet.t =
  match succ_of_lval lv x with
  | None -> LSet.empty
  | Some succ_v -> aliases_of_vertex succ_v x

let points_to_set (lv:lval) (x:t) : LSet.t =
  match succ_of_lval lv x with
  | None -> LSet.empty
  | Some succ_v -> find_lset succ_v x

let get_graph (x:t) = x.graph

(* renamed for the interface *)
let get_lval_set = find_lset


(* printing functions *)

let print_debug fmt (x:t) =
  Format.fprintf fmt "@[<v>";
  Format.fprintf fmt "@[Edges:";
  G.iter_edges (fun v1 v2 -> Format.fprintf fmt "@;<3 2>@[%d → %d@]" v1 v2) x.graph;
  Format.fprintf fmt "@]@;<6>";
  Format.fprintf fmt "@[LMap:@;<3 2>";
  LLMap.pretty fmt x.lmap;
  Format.fprintf fmt "@]@;<6>";
  Format.fprintf fmt "@[VMap:@;<2>";
  VMap.iter (fun v ls -> Format.fprintf fmt "@;<2 2>@[%d:%a@]" v LSet.pretty ls) x.vmap;
  Format.fprintf fmt "@]";
  Format.fprintf fmt "@]"

let print_graph fmt (x:t) =
  let is_first = ref true in
  let print_edge v1 v2 =
    if !is_first then is_first := false else Format.fprintf fmt "@;<3>";
    let print_node v fmt lset = Format.fprintf fmt "%d:%a" v LSet.pretty lset in
    Format.fprintf fmt "@[%a@] → @[%a@]"
      (print_node v1) (VMap.find v1 x.vmap)
      (print_node v2) (VMap.find v2 x.vmap)
  in
  if G.nb_edges x.graph = 0
  then Format.fprintf fmt "<empty>"
  else G.iter_edges print_edge x.graph

let print_aliases fmt (x:t) =
  let is_first = ref true in
  let print_alias_set _ set_lv =
    if !is_first then is_first := false else Format.fprintf fmt "@;<2>";
    LSet.pretty fmt set_lv
  in
  let alias_set_of_vertex i _ =
    let aliases = aliases_of_vertex i x in
    if LSet.cardinal aliases >= 2 then Some aliases else None
  in
  let alias_sets = VMap.filter_map alias_set_of_vertex x.vmap in
  if VMap.is_empty alias_sets
  then Format.fprintf fmt "<none>"
  else VMap.iter print_alias_set alias_sets

(** invariants of type t must be true before and after each functon call *)
let assert_invariants (x:t) : unit =
  (* check that all vertex of the graph have entries in vmap,
     and are integer between 0 and node_counter, and have at most 1 successor *)
  assert (!node_counter >= 0);
  let assert_vertex (v:V.t) =
    assert (v >= 0);
    assert (v < !node_counter);
    assert (VMap.mem v x.vmap);
    assert (List.length (G.succ x.graph v) <= 1)
  in
  G.iter_vertex assert_vertex x.graph;
  let assert_edge v1 v2 =
    assert (v1 <> v2);
    assert (G.mem_vertex x.graph v1);
    assert (G.mem_vertex x.graph v2)
  in
  G.iter_edges assert_edge x.graph;
  let assert_lmap (lv : lval) (v:V.t) =
    assert (G.mem_vertex x.graph v);
    assert (LSet.mem lv (VMap.find v x.vmap))
  in
  LLMap.iter assert_lmap x.lmap;
  let assert_vmap (v:V.t) (ls:LSet.t) =
    assert (G.mem_vertex x.graph v);
    (* TODO: we removed the invariant because of OSCS*)
    (* if not (LSet.is_empty ls)
     * then
     *   begin
     *     let lv = LSet.choose ls in
     *     let is_ptr_lv = Lval.is_pointer lv in
     *     assert (LSet.for_all (fun x -> Lval.is_pointer x = is_ptr_lv) ls)
     *   end; *)
    assert (LSet.fold (fun lv acc -> acc && V.equal (LLMap.find lv x.lmap) v) ls true)
  in
  VMap.iter assert_vmap x.vmap

(* Ensure that assert_invariants is not executed if the -noassert flag is supplied. *)
let assert_invariants x = assert (assert_invariants x; true)

let pretty ?(debug = false) fmt (x:t) =
  if debug then
    try
      assert_invariants x;
      print_graph fmt x
    with Assert_failure _ -> print_debug fmt x
  else
    print_aliases fmt x

(** .dot printing functions*)
let find_vertex_name_ref = Extlib.mk_fun "find_vertex_name"

let lset_to_string (s: LSet.t) : string =
  let fmt = Format.str_formatter in
  Format.fprintf fmt "\"%a\"" LSet.pretty s;
  Format.flush_str_formatter ()

module Dot = Graphviz.Dot (struct
    include G
    let edge_attributes _ = []
    let default_edge_attributes _ = []
    let get_subgraph _ = None
    let vertex_attributes _ = [`Shape `Box]
    let vertex_name (v:V.t) =
      let lset = !find_vertex_name_ref v in
      lset_to_string lset
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

(* find functions, part 2 *)
let rec closure_find_lset (v:V.t) (x:t) : (V.t * LSet.t) list =
  match G.succ x.graph v with
    [] -> [v, find_lset v x]
  | [v_next] -> (v, find_lset v x)::(closure_find_lset v_next x)
  | _ -> Options.fatal ("this shall not happen (invariant broken)")

let find_transitive_closure  (lv:lval) (x:t) : (G.V.t * LSet.t) list =
  let lv = Lval.simplify lv in
  assert_invariants x;
  try
    let v = (LLMap.find lv x.lmap) in
    closure_find_lset v x
  with
    Not_found -> []
(* TODO : what about offsets ? *)

(* NOTE on "constant vertex": a constant vertex represents an unamed
   scalar value (type bottom in steensgaard's paper), or the address
   of a variable. It means that in [vmap], its associated LSet is
   empty.  By definition, constant vertex cannot be associated to a
   lval in [lmap] *)
let create_cst_vertex (x:t) : V.t * t =
  let new_v = fresh_node_id () in
  new_v,
  {
    graph = G.add_vertex x.graph new_v;
    lmap = x.lmap ;
    vmap = VMap.add new_v LSet.empty x.vmap
  }

(* find all the aliases of lv1 in x, for create_vertex *)
let find_all_aliases_of_offset (lv1 : lval) (x: t) : LSet.t =

  let list_of_lval_to_be_searched : (lval * offset) list =
    decompose_lval lv1
  in
  (* for each lval, find the set of aliases *)
  let f_map (lv,o) =
    try (VMap.find (LLMap.find lv x.lmap) x.vmap, o)
    with
      Not_found -> (LSet.empty,o)
  in
  Options.debug ~level:9 "decompose_lval %a : [@[<hov 2>" Lval.pretty lv1;
  List.iter (fun (x, o) -> Options.debug ~level:9 " (%a,%a) " Lval.pretty x Offset.pretty o) list_of_lval_to_be_searched;
  Options.debug ~level:9 "@]]";
  let list_of_aliases : (LSet.t*offset) list =
    List.map f_map list_of_lval_to_be_searched
  in
  (*  for each lval of the Lset, add the offset and add it to the resulting set *)
  let f_fold_left (acc:LSet.t) (ls,o) =
    LSet.fold
      (fun lv -> let lv = Cil.addOffsetLval o lv in LSet.add lv)
      ls
      acc
  in
  List.fold_left f_fold_left (LSet.singleton lv1) list_of_aliases

(* returns the new vertex and the new graph *)
(* only for function find_or_create vertex *)
let create_vertex_simple (lv:lval) (x:t) : V.t * t =
  let new_v = fresh_node_id () in
  let new_g = G.add_vertex x.graph new_v in
  (* find all the alias of lv (because of offset) *)
  let set_of_aliases : LSet.t = find_all_aliases_of_offset lv x in
  (* add all these aliases *)
  Options.debug ~level:9 "all_aliases of %a : %a " Lval.pretty lv LSet.pretty set_of_aliases;
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
      lmap = new_lmap ;
      vmap = new_vmap ;
    }
  in
  assert_invariants new_x;
  match lv with
  | Var v, NoOffset ->
    begin
      match v.vtype with
        TPtr _ ->
        (* then add a constant vertex *)
        let another_v, new_x = create_cst_vertex new_x in
        let new_g = G.add_edge new_x.graph new_v another_v in
        new_v, {new_x with graph = new_g}
      | _ -> new_v, new_x
    end
  | _ -> new_v , new_x

let diff_offset (lv1 : lval) (lv2 : lval) =
  let rec f_diff_offset o1 o2 =
    match o1, o2 with
      NoOffset, _ -> o2
    | Field (_,o1), Field (_,o2) -> f_diff_offset o1 o2
    | Index (_,o1), Index (_,o2) -> f_diff_offset o1 o2
    | _ -> Options.fatal "%s: unexpected case" __LOC__
  in
  let _, o1 = Cil.removeOffsetLval lv1
  and _, o2 = Cil.removeOffsetLval lv2
  in
  assert (LLMap.is_sub_offset o1 o2);
  f_diff_offset o1 o2

let rec create_vertex lv x =
  Options.debug ~level:9 "creating a vertex for %a" Lval.pretty lv;
  assert (not (LLMap.mem lv x.lmap));
  begin
    match lv with
      (Mem e, NoOffset) ->
      (* special case, when we also add another vertex and a points-to edge*)
      begin
        (* first find the vertex corresponding to e *)
        match Lval.from_exp e with
        | None -> Options.fatal "unexpected result: Lval.from (%a) = None" Exp.pretty e
        | Some (BAddrOf _) -> Options.fatal "unexpected: *(&x)"
        | Some (BLval lv1) ->
          (* find the vertex *)
          let v1, x = find_or_create_vertex (BLval lv1) x in
          (* then creates a vertex for bvl ONLY IF there is no successor *)
          begin
            match G.succ x.graph v1 with
              [] ->
              let v2, x = create_vertex_simple lv x in
              (* finally add a points-to edge between v1 and v2 *)
              let new_graph = G.add_edge x.graph v1 v2 in
              v2, {x with graph = new_graph }
            | [succ_v1] ->
              (* if there is a successor, update lmap and vmap to add blv to that successor's set *)
              let new_lmap = LLMap.add lv succ_v1 x.lmap in
              let new_vmap = VMap.add succ_v1 (LSet.add lv (VMap.find succ_v1 x.vmap)) x.vmap in
              succ_v1, {x with lmap = new_lmap ; vmap = new_vmap }
            | _ -> Options.fatal " Invariant violated : more than 1 successor"
          end
      end
    | _ -> create_vertex_simple lv x
  end

and find_or_create_lval_vertex (lv:lval) (x:t) : V.t * t =
  try LLMap.find lv x.lmap, x
  with Not_found ->
    (* try to find if an alias already exists in x *)
    let map_predecessors : V.t LMap.t =
      LLMap.find_upper_offsets lv x.lmap
    in
    (* for any predecessor, find all its aliases and then look for potential existing vertex *)
    let f_fold_lmap lvx vx acc =
      let set_aliases = VMap.find vx x.vmap in
      Options.debug ~level:9 "looking for aliases of %a in set %a" Lval.pretty lv LSet.pretty set_aliases;
      if LSet.cardinal set_aliases <= 1 then acc else
        let off = diff_offset lvx lv in
        let f_fold_lset lvs acc =
          try
            let lvs = Cil.addOffsetLval off lvs in
            VSet.add (LLMap.find lvs x.lmap) acc
          with
            Not_found -> acc
        in
        LSet.fold f_fold_lset set_aliases acc
    in
    (* set of all existing aliases *)
    let vset_res = LMap.fold f_fold_lmap map_predecessors VSet.empty in
    Options.debug ~level:9 "found aliases of %a : %a" Lval.pretty lv VSet.pretty vset_res;
    if VSet.is_empty vset_res
    then create_vertex lv x
    else
      let () = assert (VSet.cardinal vset_res = 1) in
      let v_res = VSet.choose vset_res in
      (* vertex found, update the tables *)
      let new_lmap = LLMap.add lv v_res x.lmap in
      let new_vmap = VMap.add v_res (LSet.add lv (VMap.find v_res x.vmap)) x.vmap in
      v_res, {x with lmap = new_lmap; vmap = new_vmap}

(* find the vertex of an lval *)
and find_or_create_vertex (lv:slval) (x:t) : V.t * t =
  match lv with
  | BLval lv -> find_or_create_lval_vertex lv x 
  | BAddrOf lv ->
    Options.debug ~level:9 "creating a vertex for %a" Simplified.pretty (BAddrOf lv);
    let v1, x = find_or_create_lval_vertex lv x in
    let va, x = create_cst_vertex x in
    va, {x with graph = G.add_edge x.graph va v1}

(* TODO is there a better way to do it ? *)
let find_vertex lv x =
  let lv = Lval.simplify lv in
  let v,x1 = find_or_create_lval_vertex lv x in
  if x == x1
  (* if x has not been modified, then the vertex was found, not created *)
  then v
  else raise Not_found

(* merge of two vertices; the first vertex carries both sets, the second is removed from the graph and from lmap and vmap *)
let merge x v1 v2 =
  if (V.equal v1 v2) || not (G.mem_vertex x.graph v1) || not (G.mem_vertex x.graph v2)
  then x
  else
    let set1 = find_lset v1 x in
    let set2 = find_lset v2 x in

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
    {graph = g; lmap = new_lmap; vmap = new_vmap}

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
    | [], _ -> x
    | _, [] -> x
    | [succ_v1],[succ_v2] ->
      assert (succ_v1 <> v2);
      assert (succ_v2 <> v1);
      join_without_check x succ_v1 succ_v2
    | _, _ ->
      Options.fatal "invariant broken"

(* since the recursive version of join, unify, unify2 and merge may break the invariants *)
let join (x:t) (v1:V.t) (v2:V.t) : t =
  Options.debug ~level:7 "graph before join(%d,%d):@;<2>@[%a@]" v1 v2 print_debug x;
  assert_invariants x;
  let res = join_without_check x v1 v2 in
  Options.debug ~level:7 "graph after join(%d,%d):@;<2>@[%a@]" v1 v2 print_debug res;
  begin
    try assert_invariants res
    with Assert_failure _ ->
      Options.debug "join(%d,%d) failed" v1 v2;
      Options.debug "graph before join(%d,%d):@;<2>@[%a@]" v1 v2 print_debug x;
      Options.debug "graph after join(%d,%d):@;<2>@[ %a@]" v1 v2 print_debug res;
      assert_invariants res
  end;
  res

let merge_set (x:t) (vs:VSet.t) : V.t * t =
  let v0 = VSet.choose vs in
  if VSet.cardinal vs < 2 then v0, x else begin
    Options.debug ~level:7 "graph before merge_set %a:@;<2>@[%a@]" VSet.pretty vs print_debug x;
    assert (G.mem_vertex x.graph v0);
    let result = VSet.fold (fun v acc -> merge acc v0 v) vs x in
    Options.debug ~level:7 "graph after merge_set %a:@;<2>@[%a@]" VSet.pretty vs print_debug result;
    v0, result
  end

let rec join_succs (x:t) v =
  Options.debug ~level:8 "joining successors of %d" v;
  if not @@ G.mem_vertex x.graph v then x else
    match G.succ x.graph v with
    | [] | [_] -> x
    | succs ->
      let v0, x = merge_set x @@ VSet.of_list succs in
      join_succs x v0

(* in Steensgard's paper, this is written settype(v1,ref(v2,bot)) *)
let set_type (x:t) (v1:V.t) (v2:V.t) : t =
  assert_invariants x;
  (* if v1 points to another node, suppress current outgoing edge (and the node if it is a constant node) *)
  let g, new_vmap =
    match G.succ x.graph v1 with
      [] -> x.graph, x.vmap
    | [v2] ->
      (* if v2 is a constant node supress it directly *)
      if LSet.is_empty (VMap.find v2 x.vmap)
      then (G.remove_vertex x.graph v2, VMap.remove v2 x.vmap)
      else (G.remove_edge x.graph v1 v2, x.vmap)
    | _ -> Options.fatal "too many outgoing edges in set_type"
  in
  let new_g = G.add_edge g v1 v2 in
  let new_x = {x with graph = new_g ; vmap = new_vmap} in
  assert_invariants new_x ; new_x

let assignment (a:t) (lv:lval) (e:exp) : t =
  assert_invariants a;
  if not @@ Cil.isPointerType (Cil.typeOf e) then a else
    let x = Lval.simplify lv in
    match Lval.from_exp e with
    | None -> a
    | Some y ->
      let (v1,a) = find_or_create_lval_vertex x a in
      let (v2,a) = find_or_create_vertex y a in
      if List.mem v2 (G.succ a.graph v1) || List.mem v1 (G.succ a.graph v2)
      then
        let () =
          Options.warning ~source:(fst e.eloc)
            "ignoring assignment of the form: %a = %a"
            Printer.pp_lval lv Printer.pp_exp e;
        in a
      else
        let a = join a v1 v2 in
        let () = assert_invariants a in
        a

(* assignment x = allocate(y) *)
let assignment_x_allocate_y (a:t) (lv:lval) : t =
  assert_invariants a;
  let x = Lval.simplify lv in
  let (v1,a) = find_or_create_lval_vertex x a in
  match G.succ a.graph v1 with
  | [] ->
    let (v2,a) = create_cst_vertex a in
    let new_a : t = set_type a v1 v2 in
    let () = assert_invariants new_a in new_a
  | [_v2] -> a
  | _ -> Options.fatal "this should not hapen (invariant broken)"

let is_included (a1:t) (a2:t) =
  (* tests if a1 is included in a2, at least as the nodes with lval *)
  assert_invariants a1;
  assert_invariants a2;
  Options.debug ~level:8 "testing equal %a AND à.%a" (pretty ~debug:true) a1 (pretty ~debug:true) a2;
  let exception Not_included in
  try
    let iter_lmap (lv : lval) (v1:V.t): unit =
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

let empty :t =
  {graph = G.empty; lmap = LLMap.empty; vmap = VMap.empty}

let is_empty s =
  compare s empty = 0

(* add an int to all vertex values *)
let shift (a : t) : t =
  assert_invariants a;
  if is_empty a then a else
    let () = Options.debug ~level:8 "before shift: node_counter=%d@.%a" !node_counter print_debug a in
    let max_idx = G.fold_vertex max a.graph 0 in
    let min_idx = G.fold_vertex min a.graph max_idx in
    let offset = !node_counter - min_idx in
    let shift x = x + offset in
    let shift_vmap shift_elem vmap =
      VMap.of_seq @@ Stdlib.Seq.map shift_elem @@ VMap.to_seq vmap
    in
    let {graph; lmap; vmap} = a in
    node_counter := max_idx + offset + 1;
    let result =
      {graph = G.map_vertex shift graph;
       lmap = LLMap.map shift lmap;
       vmap = shift_vmap (fun (key, l) -> (shift key, l)) vmap}
    in
    let () = Options.debug ~level:8 "after shift: node_counter=%d@.%a" !node_counter print_debug result in
    assert_invariants result;
    result

let union_find vmap intersections =
  let module Store : UnionFind.STORE = UnionFind.StoreMap.Make (VMap) in
  let module UF = UnionFind.Make (Store) in
  let uf = UF.new_store () in
  let refs = VMap.mapi (fun i _ -> UF.make uf i) vmap in
  let put_into_uf (v1,v2) =
    let r1 = VMap.find v1 refs in
    let r2 = VMap.find v2 refs in
    ignore @@ UF.union uf r1 r2
  in
  let _vs = Seq.iter put_into_uf intersections in
  let sets_to_be_joined =
    let add_to_map i r sets =
      let repr = UF.find uf r in
      let add_to_set = function
        | None -> Some (VSet.singleton i)
        | Some set -> Some (VSet.add i set)
      in
      VMap.update (UF.get uf repr) add_to_set sets
    in
    VMap.fold add_to_map refs VMap.empty in
  sets_to_be_joined

let union (a1:t) (a2:t) :t =
  (* naive algorithm :
     1 merge the graph and the vmap (by doing union of sets)
     2 for any node present in both a1.graph and a2.graph, merge/join them
     3 for any lval [lv] that are has an entry in both a1.lmap and a2.lmap, merge the two vertex a1.lmap[lv]
       and a2.lmap[lv]

     I am not confident about this function, there are too many potential bugs and inefficiencies
  *)
  assert_invariants a1;
  assert_invariants a2;

  Options.debug ~level:4 "Union: First graph:%a" print_graph a1;
  Options.debug ~level:5 "Union: First graph:%a" print_debug a1;
  Options.debug ~level:4 "Union: Second graph:%a" print_graph a2;
  Options.debug ~level:5 "Union: Second graph:%a" print_debug a2;
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
  let new_vmap =
    VMap.union (fun _ lset1 lset2 -> Option.some @@ LSet.union lset1 lset2)
      a2.vmap
      a1.vmap
  in
  let sets_to_be_joined =
    let intersections = LLMap.to_seq @@ LLMap.intersect a1.lmap a2.lmap in
    union_find new_vmap @@ Seq.map (fun (_,_,x) -> x) intersections
  in
  let new_lmap = LLMap.union a1.lmap a2.lmap in
  Options.debug ~level:7 "Union: sets to be joined:@[";
  VMap.iter (fun _ set -> Options.debug ~level:7 "%a" VSet.pretty set) sets_to_be_joined;
  Options.debug ~level:7 "@]";
  let new_a = {graph = new_graph; lmap = new_lmap; vmap = new_vmap} in
  let merged_nodes, new_a =
    VMap.fold
      (fun _ set (merged_nodes, x) -> let v0, x = merge_set x set in (v0 :: merged_nodes), x)
      sets_to_be_joined
      ([], new_a)
  in
  let new_a = List.fold_left join_succs new_a merged_nodes in
  Options.debug ~level:4 "Union: Result graph:%a" print_graph new_a;
  Options.debug ~level:5 "Union: Result graph:%a" print_debug new_a;
  begin
    try assert_invariants new_a
    with Assert_failure _ ->
      Options.debug "union failed";
      Options.debug "Union: First graph:%a" print_graph a1;
      Options.debug "Union: First graph:%a" print_debug a1;
      Options.debug "Union: Second graph:%a" print_graph a2;
      Options.debug "Union: Second graph:%a" print_debug a2;
      Options.debug "Union: Result graph:%a" print_graph new_a;
      Options.debug "Union: Result graph:%a" print_debug new_a;
      assert_invariants new_a
  end;
  new_a

(** a type for summaries of functions *)
type summary =
  {
    state : t option;
    formals: lval list;
    locals: lval list;
    return : exp option
  }

let make_summary (s : t) (kf : kernel_function) =
  let exp_return : exp option =
    if Kernel_function.has_definition kf then
      let return_stmt = Kernel_function.find_return kf in
      match return_stmt.skind with
        Return (e, _) -> e
      | _ -> Options.fatal "this should not happen"
    else
      None
  in
  let s =
    match exp_return with
      None -> s
    | Some e ->
      begin
        match s, Lval.from_exp e with
          _, None -> s
        | s, Some lv ->
          let _, new_s = find_or_create_vertex lv s in
          new_s
      end
  in
  {
    state = Some s;
    formals = List.map (fun v -> (Var v,NoOffset)) (Kernel_function.get_formals kf);
    locals = List.map (fun v -> (Var v,NoOffset))  (Kernel_function.get_locals kf);
    return = exp_return
  }

let pretty_summary ?(debug=false) fmt s =
  let print_list_lval ~state fmt (l: lval list) =
    let is_first = ref true in
    let print_elem x =
      if !is_first then is_first := false else Format.fprintf fmt "@  ";
      Format.fprintf fmt "@[%a" Cil_datatype.Lval.pretty x;
      let pointees = points_to_set x state in
      if not @@ LSet.is_empty pointees then
        Format.fprintf fmt "→%a" LSet.pretty pointees;
      Format.fprintf fmt "@]";
    in
    List.iter print_elem l
  in
  let print_option pp fmt x =
    match x with
    | Some x -> pp fmt x
    | None -> Format.fprintf fmt "<none>"
  in
  match s.state with
  | None -> if debug then Format.fprintf fmt "not found"
  | Some s when is_empty s -> if debug then Format.fprintf fmt "empty"
  | Some state ->
    begin
      Format.fprintf fmt "@[formals: @[%a@]@;<4>locals: @[%a@]@;<4>returns: @[%a@]@;<4>state: @[%a@] "
        (print_list_lval ~state) s.formals
        (print_list_lval ~state) s.locals
        (print_option Exp.pretty) s.return
        (print_option @@ pretty ~debug) s.state;
    end

(* the algorithm:
   - unify the two graphs dropping all the variables from the summary
   - pair arguments with formals assigning the formal's successor as the argument's successor
*)
let call (state:t) (res:lval option) (args:exp list) (summary:summary) :t =
  assert_invariants state;
  let formals = summary.formals in
  assert (List.length args = List.length formals);
  let sum_state = shift @@ Option.get summary.state in

  (* pair up formals and their corresponding arguments,
     as well as the bound result with the returned value *)
  let arg_formal_pairs =
    let res_ret = match res, summary.return with
      | None, None -> []
      | Some res, Some ret ->
        [BLval (Lval.simplify res), blval @@ Option.get @@ Lval.from_exp ret]
      | None, Some _ -> []
      | Some _, None -> (* Shouldn't happen: Frama-C adds missing returns *)
        Options.fatal "unexpected case: result without return"
    in
    let simplify_both (arg, formal) =
      try
        match Lval.from_exp arg with
        | None -> None
        | Some lv -> Some (lv, Lval.simplify formal)
      with Explicit_pointer_address loc ->
        Options.warning ~source:(fst loc) ~wkey:Options.Warn.unsupported_address
          "unsupported feature: explicit pointer address: %a; analysis may be unsound"
          Printer.pp_exp arg;
        None
    in
    res_ret @ List.filter_map simplify_both @@ List.combine args formals
  in

  (* for each pair (lv1,lv2) find (or create) the corresponding vertices *)
  let state, vertex_pairs =
    let state = ref state in
    let find_vertex (lv1, lv2) =
      try
        let v2 = LLMap.find lv2 sum_state.lmap in
        let v1, new_state = find_or_create_vertex lv1 !state in
        state := new_state;
        Some (v1, v2)
      with Not_found -> None
    in
    !state, List.filter_map find_vertex arg_formal_pairs
  in

  (* merge the function graph;
     for every arg/formal vertex pair (v1,v2) and every edge v2→v create edge v1→v. *)
  let g =
    let transfer_succs (g : G.t) (v1,v2) =
      let v2_succs = G.succ sum_state.graph v2 in
      assert (List.length v2_succs < 2);
      List.fold_left (fun g succ -> G.add_edge g v1 succ) g v2_succs
    in
    let g = state.graph in
    let g = G.fold_vertex (fun i g -> G.add_vertex g i) sum_state.graph g in
    let g = G.fold_edges (fun i j g -> G.add_edge g i j) sum_state.graph g in
    List.fold_left transfer_succs g vertex_pairs
  in

  (* garbage collect: remove leaf vertices from g that originate from sum_state *)
  let vertices_to_add_to_g, g =
    let g = ref g in
    let remove_if_leaf v _ =
      if G.in_degree sum_state.graph v = 0
      then let () = g := G.remove_vertex !g v in None
      else Some LSet.empty
    in
    let remaining_vertices = VMap.filter_map remove_if_leaf sum_state.vmap in
    remaining_vertices, !g
  in

  let state = {
    graph = g;
    lmap = state.lmap;
    vmap =
      let left_bias _ l _ = Some l in
      VMap.union left_bias state.vmap vertices_to_add_to_g}
  in

  let state = List.fold_left join_succs state (List.map fst vertex_pairs) in

  assert_invariants state;
  state
