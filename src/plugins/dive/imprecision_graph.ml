(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `Dive'.                      *)
(*                                                                        *)
(*  Copyright (C) 2018                                                    *)
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

open Graph_types

module Vertex =
struct
  type t = node
  let compare v1 v2 = v1.node_key - v2.node_key
  let hash v = v.node_key
  let equal v1 v2 = v1.node_key = v2.node_key
end

module Edge =
struct
  type t = dependency
  let compare e1 e2 = e1.dependency_key - e2.dependency_key
  let _hash e = e.dependency_key
  let _equal e1 e2 = e1.dependency_key = e2.dependency_key
  let default = {
    dependency_key = -1;
    dependency_kind = Data;
    dependency_multiple = false;
  }
end

module G = Graph.Imperative.Digraph.ConcreteBidirectionalLabeled (Vertex) (Edge)
include G

let next_node_key = ref 0
let next_dependency_key = ref 0

let create_node ?(node_precision=Unevaluated) ~node_kind ~node_locality g =
  let node = {
    node_key = !next_node_key;
    node_kind;
    node_locality;
    node_precision;
    node_deps_computed = false;
  }
  in
  incr next_node_key;
  add_vertex g node;
  node

let update_node_precision node new_precision =
  node.node_precision <-
    match node.node_precision, new_precision with
    | Critical, _ | _, Critical -> Critical
    | Wide, _ | _, Wide -> Wide
    | Normal, _ | _, Normal -> Normal
    | Singleton, _ | _, Singleton -> Singleton
    | Unevaluated, Unevaluated -> Unevaluated

let create_dependency ~allow_folding g v1 dependency_kind v2 =
  let same_kind (_,e,_) =
    e.dependency_kind = dependency_kind
  in
  let matching_edge =
    try
      if allow_folding then
        Some (List.find same_kind (G.find_all_edges g v1 v2))
      else
        None
    with Not_found -> None
  in
  match matching_edge with
  | Some (_,e,_) -> 
    e.dependency_multiple <- true
  | None ->
    let e = {
      dependency_key = !next_dependency_key;
      dependency_kind;
      dependency_multiple = false;
    }
    in
    incr next_dependency_key;
    add_edge_e g (v1,e,v2)


let ouptput_to_dot out_channel g =
  let open Graph.Graphviz.DotAttributes in

  let build_label s = `HtmlLabel (Extlib.html_escape s) in

  let module FileTable = Datatype.String.Hashtbl in
  let module FunctionTable = Kernel_function.Hashtbl in
  let file_table = FileTable.create 13
  and function_table = FunctionTable.create 13 in
  let file_counter = ref 0 in
  let rec build_file_subgraph filename =
    incr file_counter;
    {
      sg_name = "file_" ^ (string_of_int !file_counter);
      sg_attributes = [build_label filename];
      sg_parent = None;
    }
  and build_function_subgraph filename kf =
    {
      sg_name = "function_" ^ (string_of_int (Kernel_function.get_id kf));
      sg_attributes = [build_label (Kernel_function.get_name kf)];
      sg_parent = Some (get_file_subgraph filename).sg_name;
    }
  and get_file_subgraph filename =
    FileTable.memo file_table filename build_file_subgraph
  and get_function_subgraph filename kf =
    FunctionTable.memo function_table kf (build_function_subgraph filename)
  in

  let module Dot = Graph.Graphviz.Dot (
    struct
      include G
      let graph_attributes _g = []
      let default_vertex_attributes _g = []
      let vertex_name v = "cp" ^ (string_of_int v.node_key)
      let vertex_attributes v =
        let l = ref [] in
        let text = Pretty_utils.to_string Node_kind.pretty v.node_kind in
        if text <> "" then
          l := build_label text :: !l;
        let kind = match v.node_kind with
          | Scalar _ -> [`Shape `Box]
          | Composite _ -> [ `Shape `Box3d ]
          | Scattered _ -> [ `Shape `Parallelogram ]
          | Alarm _ ->  [ `Shape `Doubleoctagon ; `Style `Bold ]
          | File -> [ `Style `Invis ]
        and precision = match v.node_precision with
          | Unevaluated -> []
          | Singleton -> [`Color 0x88aaff ;
                          `Style `Filled ; `Fillcolor 0xaaccff]
          | Normal -> [ `Color 0x004400 ;
                        `Style `Filled ; `Fillcolor 0xeeffee ]
          | Wide -> [ `Color 0xff0000 ;
                      `Style `Filled ; `Fillcolor 0xffbbbb ]
          | Critical -> [ `Color 0xff0000 ; `Style `Bold ;
                          `Style `Filled ; `Fillcolor 0xff0000 ]
        in
        l := precision @ kind @ !l;
        if not v.node_deps_computed then
          l := [ `Style `Dotted ] @ !l;
        !l
      let get_subgraph v =
        let {loc_file ; loc_function} = v.node_locality in
          match loc_function with
            | None -> Some (get_file_subgraph loc_file)
            | Some kf -> Some (get_function_subgraph loc_file kf)
      let default_edge_attributes _g = []
      let edge_attributes (_v1,e,_v2) =
        let kind_attribute = match e.dependency_kind with
          | Callee -> [`Color 0x00ff00 ]
          | _ -> []
        and folding_attribute = match e.dependency_multiple with
          | true -> [ `Style `Bold ]
          | false -> []
        in kind_attribute @ folding_attribute 
    end)
  in
  Dot.output_graph out_channel g

let ouptput_to_json out_channel g =
  let output_node_kind kind =
    let s = match kind with
      | Scalar _ -> "scalar"
      | Composite _ -> "composite"
      | Scattered _ -> "scattered"
      | Alarm _ -> "alarm"
      | File -> "dummy"
    in
    Json.of_string s
  and output_node_locality { loc_file ; loc_function } =
    let f1 = ("file", Json.of_string loc_file) in
    let fields = match loc_function with
      | None -> [f1]
      | Some kf -> [f1 ; ("fun", Json.of_string (Kernel_function.get_name kf))]
    in
    Json.of_fields fields
  and output_node_precision precision =
    let s = match precision with
      | Unevaluated -> "unevaluated"
      | Singleton -> "singleton"
      | Normal -> "normal"
      | Wide -> "wide"
      | Critical -> "critical"
    in
    Json.of_string s
  and output_dep_kind kind =
    let s = match kind with
      | Callee -> "callee"
      | Data -> "data"
      | Address -> "addr"
      | Control -> "ctrl"
    in
    Json.of_string s
  in
  let output_node node acc =
    if node.node_kind = File then acc
    else
      let label = Pretty_utils.to_string Node_kind.pretty node.node_kind in
      Json.of_fields [
        ("id", Json.of_int node.node_key) ;
        ("label", Json.of_string label) ;
        ("kind", output_node_kind node.node_kind) ;
        ("locality", output_node_locality node.node_locality) ;
        ("precision", output_node_precision node.node_precision) ;
        ("explored", Json.of_bool node.node_deps_computed)
      ] :: acc
  and output_dep (n1,dep,n2) acc =
    Json.of_fields [
      ("id", Json.of_int dep.dependency_key) ;
      ("src", Json.of_int n1.node_key) ;
      ("dst", Json.of_int n2.node_key) ;
      ("kind", output_dep_kind dep.dependency_kind) ;
      ("multiple", Json.of_bool dep.dependency_multiple)
    ] :: acc
  in
  let nodes = Json.of_list (fold_vertex output_node g [])
  and deps = Json.of_list (fold_edges_e output_dep g []) in
  let json = Json.of_fields [("nodes", nodes) ; ("deps", deps)] in
  Json.save_channel ~pretty:true out_channel json