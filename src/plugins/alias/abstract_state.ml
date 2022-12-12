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

module LSet = Lval.Set

module LMap = Lval.Map

(** module for vertices *)
module V = struct

  type t =
    {
      id : Int.t; (* id must be unique in a graph *)
      set : LSet.t
    }

  let cmpt_v = ref (-1)

  let new_id () = incr cmpt_v; !cmpt_v

  let compare x y = Int.compare x.id y.id

  let hash x = Hashtbl.hash x.id (* toto utiliser fonction hash frama-c *)

  let equal x y = (compare x y = 0)

  let create s = { id = new_id () ; set = s}

  let label x = x.set

end


module G = Persistent.Digraph.Concrete(V)

type t = G.t

(* printing functions *)
let pretty fmt (x:t) =
  Format.fprintf fmt "@[<hov 2>List of vertices: @.";
  G.iter_vertex (fun v -> Format.fprintf fmt "(id=%d LSet= %a)@." v.id LSet.pretty v.set) x;
  Format.fprintf fmt "@]@.@[<hov 2>List of edges: @.";
  G.iter_edges (fun v1 v2 -> Format.fprintf fmt "(%d -> %d)@." v1.id v2.id) x;
  Format.fprintf fmt "@]@."

let lset_to_string s =
  let buffer = Buffer.create 16 in
  let fmt = Format.formatter_of_buffer buffer in
  Format.fprintf fmt "%a" LSet.pretty s ;
  Buffer.contents buffer

module Dot = Graphviz.Dot(struct
    include G
    let edge_attributes _ = []
    let default_edge_attributes _ = []
    let get_subgraph _ = None
    let vertex_attributes _ = [`Shape `Box]
    let vertex_name (v:V.t) = lset_to_string v.set
    let default_vertex_attributes _ = []
    let graph_attributes _ = []
  end)

let print_dot filename (graph:t) =
  let file = open_out filename in
  Dot.output_graph file graph;
  close_out file

(* merge of two vertices; returns the new vertex as well as the graph *)
let merge g v1 v2 =
  if v1 = v2
  then None,g
  else
    let new_set = LSet.union (V.label v1) (V.label v2) in
    let new_vertex = V.create new_set in
    let g = G.add_vertex g new_vertex in
    let f_fold_succ v_succ (g:t) : t=
      G.add_edge g new_vertex v_succ
    and f_fold_pred v_pred (g:t) :t =
      G.add_edge g v_pred new_vertex
    in
    (* adds all new edges *)
    let g = G.fold_succ f_fold_succ g v1 g in
    let g = G.fold_succ f_fold_succ g v2 g in
    let g = G.fold_pred f_fold_pred g v1 g in
    let g = G.fold_pred f_fold_pred g v2 g in
    (* remove the two old vertices *)
    let g = G.remove_vertex g v1 in
    (Some new_vertex , G.remove_vertex g v2)

(* find the vertex of an lval, unefficient version *)
exception Found of V.t

let unefficient_find_vertex g (lv:lval) : V.t =
  let f_iter v =
    if LSet.mem lv (V.label v)
    then raise (Found v)
  in
  try (G.iter_vertex f_iter g ; raise Not_found) with
  | Found v -> v

(* find the vertex of an lval thanks to a map Lval -> V.t *)
let find_vertex ?(map=LMap.empty) g lv =
  try LMap.find lv map with
    Not_found -> unefficient_find_vertex g lv

let points_to ?(map=LMap.empty) g (lv:lval) : V.t list =
  let v = find_vertex ~map g lv in
  G.succ g v

(** functions for steensgard's algorithm *)

(* efficiency can be improved here *)
module VSet = Set.Make(V)
module VMap = Map.Make(V)

(* helper for the algorithms ; must be given as an argument of every function, and updated with the graph *)
type helper = {pending : VSet.t VMap.t ; lmap : V.t LMap.t}
(* In the long term this shall be in the type t (instead of having LSet in each vertex) *)

(* functions join and unify-pointer of steensgaard's paper *)
let rec join (h:helper) (g:t) (v1:V.t) (v2:V.t) =
  if not (G.mem_vertex g v1 && G.mem_vertex g v2)
  then
    (h,g)
  else
    let pt1 = G.succ g v1 in
    let pt2 = G.succ g v2 in
    let new_v_opt,g = merge g v1 v2 in
    match new_v_opt with
      None -> (h,g)
    | Some new_v ->
      (* update lmap *)
      let m = LSet.fold (fun lv m -> LMap.add lv new_v m) (V.label new_v) h.lmap in
      if pt1 = []
      then
        if pt2 = []
        then
          (* update pending *)
          let p = VMap.add new_v (VSet.union (VMap.find v1 h.pending) (VMap.find v2 h.pending)) h.pending in
          let p = VMap.remove v1 p in
          let p = VMap.remove v2 p in
          ({pending=p; lmap=m },g)
        else
          (* join pending v1 *)
          VSet.fold
            (fun v (h,g) -> join h g v new_v)
            (try VMap.find v1 h.pending with Not_found -> VSet.empty )
            ({pending = h.pending; lmap = m },g)
      else
      if pt2 = []
      then
        (* join pending v2 *)
        VSet.fold
          (fun v (h,g) -> join h g v new_v)
          (try VMap.find v2 h.pending with Not_found -> VSet.empty )
          ({pending = h.pending; lmap = m },g)
      else
        (* join the succesors *)
        unify {pending=h.pending;lmap = m} g pt1 pt2

and unify (h:helper) (g:t) (l1:V.t list) (l2:V.t list) =
  match l1 with
    [] -> (h,g)
  | v1::qq ->
    let (h,g) = unify2 h g v1 l2 in
    unify h g qq l2

and unify2  (h:helper) (g:t) (v1:V.t) (l2:V.t list) =
  match l2 with
    [] -> (h,g)
  | v2::qq ->
    let (h,g) = join h g v1 v2 in
    unify2 h g v1 qq

let cjoin  (h:helper) (g:t) (v1:V.t) (v2:V.t) =
  let pt2=  G.succ g v2 in
  if pt2 = []
  then
    let old_set = try VMap.find v2 h.pending with Not_found -> VSet.empty in
    let new_pending = VMap.add v2 (VSet.add v2 old_set) h.pending in
    ({pending=new_pending; lmap = h.lmap}, g)
  else
    join h g v1 v2

(* in Steensgard's paper, this is written settype(v1,ref(v2,bot)) *)
let set_type (h:helper) (g:t) (v1:V.t) (v2:V.t) =
  let g = G.add_edge g v1 v2 in
  VSet.fold (fun vx (h,g) -> join h g v1 vx) (try VMap.find v1 h.pending with Not_found -> VSet.empty) (h,g)

(** a type for summaries of functions *)
type summary = t (* final type may be different *)

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

module Make_table(H: Hashtbl.S)(V: sig type t end) = struct
  type key = H.key
  type value = V.t
  let tbl = H.create 7
  let find = H.find tbl

end

module Stmt_table = Make_table(Cil_datatype.Stmt.Hashtbl)(G)
module Function_table = Make_table(Kernel_function.Hashtbl)(G)

let do_stmt _ =
  failwith "not implemented"

let make_summary  _ =
  failwith "not implemented"

let _ =
  (* dummy for compiling without " unused function" error *)
  let g = G.empty in
  let v = V.create LSet.empty in
  ignore (merge g v v);
  let dummy_exp = {eid=0;enode= Const (CStr ""); eloc = Location.unknown} in
  let dummy_lval = (Mem dummy_exp, NoOffset) in
  let h = {pending = VMap.empty ; lmap = LMap.empty } in
  ignore (h);
  ignore (points_to g dummy_lval);
  ignore (cjoin h g v v);
  ignore (set_type h g v v);
  ()

