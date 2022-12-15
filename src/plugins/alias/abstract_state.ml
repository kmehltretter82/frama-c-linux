(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2022                                               *)
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


(* (\** module for vertices *\)
 * module V = struct
 *
 *   type t =
 *     {
 *       id : Int.t; (\* id must be unique in a graph *\)
 *       set : LSet.t
 *     }
 *
 *   let cmpt_v = ref (-1)
 *
 *   let new_id () = incr cmpt_v; !cmpt_v
 *
 *   let compare x y = Int.compare x.id y.id
 *
 *   let hash x = Hashtbl.hash x.id (\* toto utiliser fonction hash frama-c *\)
 *
 *   let equal x y = (compare x y = 0)
 *
 *   let create s = { id = new_id () ; set = s}
 *
 *   let label x = x.set
 *
 * end *)


module G = Persistent.Digraph.Concrete(Datatype.Int)

module V = G.V

module VSet = Datatype.Int.Set
module VMap = Datatype.Int.Map

module LSet = Lval.Set
module LMap = Lval.Map



type t = {
  graph : G.t;
  pending : VSet.t VMap.t ; (* pending(v) is the set of vertices v' that could be aliased to v if v becomes/ is detected as a pointer *)
  lmap : V.t LMap.t ; (* lmap(lv) is the vertex v corresponding to lval lv, in other words lv is in label(v) *)
  vmap : LSet.t VMap.t ;(* reverse of lmap *)
  cmpt : Int.t ; (* counter to create new vertex *)
}

(* find functions *)
let find_lset (v:V.t) (x:t) =
  try VMap.find v x.vmap
  with Not_found -> LSet.empty

(* find the vertex of an lval *)
let find_vertex (lv:lval) (x:t) =
  LMap.find lv x.lmap
(** @raise Not_found if there is not such an lval in the graph *)

let create_vertex (lv:lval) (x:t) : V.t * t =
  let new_v = x.cmpt in
  let new_g = G.add_vertex x.graph new_v in
  let new_pending = VMap.add new_v VSet.empty x.pending in
  let new_lmap = LMap.add lv new_v x.lmap in
  let new_vmap = VMap.add new_v (LSet.singleton lv) x.vmap in
  new_v ,
  {graph = new_g ;
   pending = new_pending ;
   lmap = new_lmap ;
   vmap = new_vmap ;
   cmpt = x.cmpt+1}

let find_or_create_vertex (lv:lval) (x:t) : V.t *t =
  try find_vertex lv x , x with
    Not_found -> create_vertex lv x

let points_to(lv:lval) (x:t): V.t list =
  let (v,x) = find_or_create_vertex lv x in
  G.succ x.graph v

let addr_of (lv:lval) (x:t) : V.t list =
  let (v,x) = find_or_create_vertex lv x in
  G.pred x.graph v

(* printing functions *)
let pretty fmt (x:t) =
  Format.fprintf fmt "@[<hov 2>List of vertices: @.";
  G.iter_vertex (fun v -> Format.fprintf fmt "(id=%d LSet= %a)@." v LSet.pretty (find_lset v x)) x.graph;
  Format.fprintf fmt "@]@.@[<hov 2>List of edges: @.";
  G.iter_edges (fun v1 v2 -> Format.fprintf fmt "(%d -> %d)@." v1 v2) x.graph;
  Format.fprintf fmt "@]@."

(* let lset_to_string s =
 *   let buffer = Buffer.create 16 in
 *   let fmt = Format.formatter_of_buffer buffer in
 *   Format.fprintf fmt "%a" LSet.pretty s ;
 *   Buffer.contents buffer
 *
 * module Dot = Graphviz.Dot(struct
 *     include G
 *     let edge_attributes _ = []
 *     let default_edge_attributes _ = []
 *     let get_subgraph _ = None
 *     let vertex_attributes _ = [`Shape `Box]
 *     let vertex_name (v:V.t) = lset_to_string ()
 *     let default_vertex_attributes _ = []
 *     let graph_attributes _ = []
 *   end) *)

let print_dot _ = (* filename (graph:t) = *)
  failwith "not implemented"
(* let file = open_out filename in
 * Dot.output_graph file graph;
 * close_out file *)

(* merge of two vertices; the first vertex carries both sets, the second is removed from the graph and from lmap and vmap; however, pending is NOT updated  *)
let merge x v1 v2 =
  if V.equal v1 v2
  then x
  else
    let set1 = find_lset v1 x in
    let set2 = find_lset v2 x in
    let new_set = LSet.union set1 set2 in
    (* update lmap : every lval in v2 must now be associated with v1*)
    let new_lmap = LSet.fold (fun lv2 m -> LMap.add lv2 v1 m) set2 x.lmap in
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


(** functions for steensgard's algorithm *)


(* functions join and unify-pointer of steensgaard's paper *)
let rec join (x:t) (v1:V.t) (v2:V.t) : t =
  if not (G.mem_vertex x.graph v1 && G.mem_vertex x.graph v2)
  then
    x
  else
    let pt1 = G.succ x.graph v1 in (* TODO ask frama-c type instead of looking in the graph *)
    let pt2 = G.succ x.graph v2 in
    let x = merge x v1 v2 in
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

let cjoin  (x:t) (v1:V.t) (v2:V.t) =
  let pt2=  G.succ x.graph v2 in
  if pt2 = []
  then
    let old_set = try VMap.find v2 x.pending with Not_found -> VSet.empty in
    let new_pending = VMap.add v2 (VSet.add v2 old_set) x.pending in
    {x with pending=new_pending}
  else
    join x v1 v2

(* in Steensgard's paper, this is written settype(v1,ref(v2,bot)) *)
let set_type (x:t) (v1:V.t) (v2:V.t) =
  let new_g = G.add_edge x.graph v1 v2 in
  VSet.fold (fun vx x -> join x v1 vx) (try VMap.find v1 x.pending with Not_found -> VSet.empty) {x with graph = new_g}


(* assignment x = y *)
let assignment_x_y (a:t) (x:lval) (y:lval) : t =
  let (v1,a) = find_or_create_vertex x a in
  let (v2,a) = find_or_create_vertex y a in
  cjoin a v1 v2


(* assignment x = &y *)
let assignment_x_addr_y (a:t) (x:lval) (y:lval) : t=
  let (v1,a) = find_or_create_vertex x a in
  let list_v2 = addr_of y a in
  match list_v2 with
    [v2] ->  join a v1 v2
  | _ ->  failwith "not implemented"


(* assignment x = *y *)
let assignment_x_ptr_y (a:t) (x:lval) (y:lval) : t =
  let (v1,a) = find_or_create_vertex x a in
  let list_v2 = points_to y a in
  match list_v2 with
    [] -> let v2 = find_vertex y a in set_type a v2 v1
  | [v2] -> cjoin a v1 v2
  | _ ->  failwith "not implemented"

(* assignment x = allocate(y) *)
let assignment_x_allocate_y (a:t) (x:lval) (y:lval) : t =
  let (v1,a) = find_or_create_vertex x a in
  let (v2,a) = create_vertex y a in
  set_type a v1 v2

(* assignment *x = y *)
let assignment_ptr_x_y (a:t) (x:lval) (y:lval) : t =
  let (v2,a) = find_or_create_vertex y a in
  let list_v1 = points_to x a in
  match list_v1 with
    [] ->  let v1 = find_vertex x a in set_type a v1 v2
  |  [v1] -> cjoin a v1 v2
  | _ ->  failwith "not implemented"

(** a type for summaries of functions *)
type summary = t (* final type may be different *)

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

module Make_table(H: Hashtbl.S)(VV: sig type tt end) = struct
  type key = H.key
  type value = VV.tt
  let tbl = H.create 7
  let add = H.add tbl
  let find = H.find tbl

end

module A = struct type tt = t end

module Stmt_table = Make_table(Cil_datatype.Stmt.Hashtbl)(A)
module Function_table = Make_table(Kernel_function.Hashtbl)(A)

let do_assignment (a:t) (lv:lval) (exp:exp) =
  match (lv,exp.enode) with
    ((Var v1, NoOffset), Lval (Var v2,NoOffset)) ->
    (* case x = y *)
    assignment_x_y a (Var v1, NoOffset) (Var v2, NoOffset)
  | ((Var v1, NoOffset), AddrOf lv2) ->
    (* case x = &y *)
    assignment_x_addr_y a (Var v1, NoOffset) lv2
  | ((Var v1, NoOffset), Lval (Mem e2, NoOffset)) ->
    (* case x  = *y *)
    begin
      match e2.enode with
        Lval lv2 -> assignment_x_ptr_y a (Var v1, NoOffset) lv2
      |  _ -> failwith "not implemented"
    end
  | ((Mem e1, NoOffset), Lval lv2) ->
    (* case *x = y *)
    begin
      match e1.enode with
        Lval lv1 -> assignment_ptr_x_y a lv1 lv2
      |  _ -> failwith "not implemented"
    end
  | _ -> failwith "not implemented"

let do_instr (a:t) (i:instr) =
  match i with
    Set(lv,exp,_) -> do_assignment a lv exp
  | _ -> failwith "not implemented"

let do_stmt (a:t) (s:stmt) =
  let new_a =
    match s.skind with
    | Instr i -> do_instr a i
    | _ -> failwith "not implemented"
  in
  Stmt_table.add s new_a ; new_a

let make_summary  _ =
  failwith "not implemented"


