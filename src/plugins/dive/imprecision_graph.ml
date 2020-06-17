(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `Dive'.                      *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

module Node =
struct
  type t = node
  let compare v1 v2 = v1.node_key - v2.node_key
  let hash v = v.node_key
  let equal v1 v2 = v1.node_key = v2.node_key
end

module Dependency =
struct
  type t = dependency
  let compare e1 e2 = e1.dependency_key - e2.dependency_key
  let hash e = e.dependency_key
  let equal e1 e2 = e1.dependency_key = e2.dependency_key
  let default = {
    dependency_key = -1;
    dependency_kind = Data;
    dependency_multiple = false;
  }
end

module G =
  Graph.Imperative.Digraph.ConcreteBidirectionalLabeled (Node) (Dependency)
include G

let vertices g =
  fold_vertex (fun n acc -> n ::acc) g []

let edges g =
  fold_edges_e (fun d acc -> d ::acc) g []

let next_key = ref 0

let create_node ~node_kind ~node_locality g =
  let node = {
    node_key = !next_key;
    node_kind;
    node_locality;
    node_hidden = false;
    node_int_values = None;
    node_float_values = None;
    node_deps_computed = false;
  }
  in
  incr next_key;
  add_vertex g node;
  node

let remove_node = remove_vertex

let union_int_interval i1 i2 =
  { min = Integer.min i1.min i2.min ; max = Integer.max i1.max i2.max }

let union_float_interval i1 i2 =
  { min = min i1.min i2.min ; max = max i1.max i2.max }

let worst_precision_grade q1 q2 =
  match q1, q2 with
  | Wide, _ | _, Wide -> Wide
  | Normal, _ | _, Normal -> Normal
  | Singleton, Singleton -> Singleton

let merge_int_values p1 p2 =
  (* TODO: prevent assertion failure *)
  assert (Integer.equal p1.values_limits.min p2.values_limits.min);
  assert (Integer.equal p1.values_limits.max p2.values_limits.max);
  {
    values_interval = union_int_interval p1.values_interval p2.values_interval;
    values_limits = p1.values_limits;
    values_grade = worst_precision_grade p1.values_grade p2.values_grade;
  }

let merge_float_values p1 p2 =
  (* TODO: prevent assertion failure *)
  assert (p1.values_limits = p2.values_limits);
  {
    values_interval = union_float_interval p1.values_interval p2.values_interval;
    values_limits = p1.values_limits;
    values_grade = worst_precision_grade p1.values_grade p2.values_grade;
  }

let update_node_int_values node new_values =
  node.node_int_values <-
    Some (Extlib.opt_fold merge_int_values node.node_int_values new_values)

let update_node_float_values node new_values =
  node.node_float_values <-
    Some (Extlib.opt_fold merge_float_values node.node_float_values new_values)


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
      dependency_key = !next_key;
      dependency_kind;
      dependency_multiple = false;
    }
    in
    incr next_key;
    add_edge_e g (v1,e,v2)

let remove_dependency g edge =
  remove_edge_e g edge


let find_independant_nodes g roots =
  let module Dfs = Graph.Traverse.Dfs (struct
      include G
      let iter_succ = G.iter_pred
      let fold_succ = G.fold_pred
    end)
  in
  let module Table = Hashtbl.Make (Node) in
  let table = Table.create 13 in
  List.iter (Dfs.prefix_component (fun n -> Table.add table n true) g) roots;
  fold_vertex (fun n acc -> if Table.mem table n then acc else n :: acc) g []


let ouptput_to_dot out_channel g =
  let open Graph.Graphviz.DotAttributes in
  (* let g = add_dummy_nodes g in *)

  let build_label s = `HtmlLabel (Extlib.html_escape s) in

  let module FileTable = Datatype.String.Hashtbl in
  let module CallstackTable = Value_types.Callstack.Hashtbl in
  let file_table = FileTable.create 13
  and callstack_table = CallstackTable.create 13 in
  let file_counter = ref 0 in
  let callstack_counter = ref 0 in
  let rec build_file_subgraph filename =
    incr file_counter;
    {
      sg_name = "file_" ^ (string_of_int !file_counter);
      sg_attributes = [build_label filename];
      sg_parent = None;
    }
  and build_callstack_subgraph = function
    | [] -> None
    | (kf,_kinstr) :: stack ->
      let parent = get_callstack_subgraph stack in
      incr callstack_counter;
      Some {
        sg_name = "cs_" ^ (string_of_int !callstack_counter);
        sg_attributes = [build_label (Kernel_function.get_name kf)];
        sg_parent = Extlib.opt_map (fun sg -> sg.sg_name) parent;
      }
  and get_file_subgraph filename =
    FileTable.memo file_table filename build_file_subgraph
  and get_callstack_subgraph cs =
    CallstackTable.memo callstack_table cs build_callstack_subgraph
  in

  let module Dot = Graph.Graphviz.Dot (
    struct
      include G
      let graph_attributes _g = []
      let default_vertex_attributes _g = []
      let vertex_name v = "cp" ^ (string_of_int v.node_key)
      let vertex_attributes v =
        let grade = match v.node_int_values, v.node_float_values with
          | Some v1, Some v2 ->
            Some (worst_precision_grade v1.values_grade v2.values_grade)
          | Some v, _ -> Some v.values_grade
          | _, Some v -> Some v.values_grade
          | None, None -> None
        in
        let l = ref [] in
        let text = Pretty_utils.to_string Node_kind.pretty v.node_kind in
        if text <> "" then
          l := build_label text :: !l;
        let kind = match v.node_kind with
          | Scalar _ -> [`Shape `Box]
          | Composite _ -> [ `Shape `Box3d ]
          | Scattered _ -> [ `Shape `Parallelogram ]
          | Alarm _ ->  [ `Shape `Doubleoctagon ;
                          `Style `Bold ; `Color 0xff0000 ;
                          `Style `Filled ; `Fillcolor 0xff0000 ]
        and values = match grade with
          | None -> []
          | Some Singleton ->
            [`Color 0x88aaff ; `Style `Filled ; `Fillcolor 0xaaccff ]
          | Some Normal ->
            [ `Color 0x004400 ; `Style `Filled ; `Fillcolor 0xeeffee ]
          | Some Wide ->
            [ `Color 0xff0000 ; `Style `Filled ; `Fillcolor 0xffbbbb ]
        in
        l := values @ kind @ !l;
        if not v.node_deps_computed then
          l := [ `Style `Dotted ] @ !l;
        !l
      let get_subgraph v =
        let {loc_file ; loc_callstack} = v.node_locality in
        match loc_callstack with
        | [] -> Some (get_file_subgraph loc_file)
        | cs -> get_callstack_subgraph cs
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

module JsonPrinter =
struct
  let output_kinstr = function
    | Cil_types.Kglobal -> `String "global"
    | Cil_types.Kstmt stmt -> `Int stmt.Cil_types.sid

  let output_callsite (kf,kinstr) =
    `Assoc [
      ("fun", `String (Kernel_function.get_name kf)) ;
      ("instr", output_kinstr kinstr) ;
    ]

  let output_callstack cs =
    `List (List.map output_callsite cs)

  let output_node_kind kind =
    let s = match kind with
      | Scalar _ -> "scalar"
      | Composite _ -> "composite"
      | Scattered _ -> "scattered"
      | Alarm _ -> "alarm"
    in
    `String s

  let output_node_locality { loc_file ; loc_callstack } =
    let f1 = ("file", `String loc_file) in
    let fields = match loc_callstack with
      | [] -> [f1]
      | cs -> [f1 ; ("callstack", output_callstack cs)]
    in
    `Assoc fields

  let output_node_precision_grade grade =
    let s = match grade with
      | Singleton -> "singleton"
      | Normal -> "normal"
      | Wide -> "wide"
    in
    `String s

  let output_dep_kind kind =
    let s = match kind with
      | Callee -> "callee"
      | Data -> "data"
      | Address -> "addr"
      | Control -> "ctrl"
      | Composition -> "comp"
    in
    `String s

  let output_int_interval interval =
    (* TODO: handle overflow *)
    `Assoc [
      ("min", `Int (Integer.to_int interval.min)) ;
      ("max", `Int (Integer.to_int interval.max)) ;
    ]

  let output_float_interval interval =
    `Assoc [
      ("min", `Float interval.min) ;
      ("max", `Float interval.max) ;
    ]

  let output_node_int_values values =
    `Assoc [
      ("computed", output_int_interval values.values_interval) ;
      ("limits", output_int_interval values.values_limits) ;
      ("grade", output_node_precision_grade values.values_grade) ;
    ]

  let output_node_float_values values =
    `Assoc [
      ("computed", output_float_interval values.values_interval) ;
      ("limits", output_float_interval values.values_limits) ;
      ("grade", output_node_precision_grade values.values_grade) ;
    ]

  let output_node node =
    let label = Pretty_utils.to_string Node_kind.pretty node.node_kind in
    `Assoc ([
        ("id", `Int node.node_key) ;
        ("label", `String label) ;
        ("kind", output_node_kind node.node_kind) ;
        ("locality", output_node_locality node.node_locality) ;
        ("explored", `Bool node.node_deps_computed) ;
      ] @
        begin match node.node_int_values with
          | None -> []
          | Some node_values ->
            [("int_values", output_node_int_values node_values)]
        end @
        begin match node.node_float_values with
          | None -> []
          | Some node_values ->
            [("float_values", output_node_float_values node_values)]
        end @
        begin match Node_kind.to_lval node.node_kind with
          | None -> []
          | Some lval ->
            let typ = Cil.typeOfLval lval in
            let str = Pretty_utils.to_string Cil_printer.pp_typ typ in
            [("type", `String str)]
        end)

  let output_dep (n1,dep,n2) =
    `Assoc [
      ("id", `Int dep.dependency_key) ;
      ("src", `Int n1.node_key) ;
      ("dst", `Int n2.node_key) ;
      ("kind", output_dep_kind dep.dependency_kind) ;
      ("multiple", `Bool dep.dependency_multiple)
    ]

  let output_graph g =
    `Assoc [
      ("nodes", `List (List.map output_node (vertices g))) ;
      ("deps", `List (List.map output_dep (edges g)))
    ]

  let output_diff g diff =
    let added_nodes = List.map output_node diff.added_nodes
    and added_deps =
      let module Set = Set.Make (struct
          type t = edge
          let compare (_,d1,_) (_,d2,_) = d1.dependency_key - d2.dependency_key
        end)
      in
      let collect_deps set node =
        let set = fold_pred_e Set.add g node set in
        let set = fold_succ_e Set.add g node set in
        set
      in
      let set = List.fold_left collect_deps Set.empty diff.added_nodes in
      List.map output_dep (Set.elements set)
    and removed_nodes =
      List.map (fun node -> `Int node.node_key) diff.removed_nodes
    in
    `Assoc [
      ("add", `Assoc [
          ("nodes", `List added_nodes) ;
          ("deps", `List added_deps)
        ]) ;
      ("sub", `List removed_nodes)]
end

let ouptput_to_json out_channel g =
  let json = JsonPrinter.output_graph g in
  Yojson.Basic.to_channel out_channel json

let to_json g =
  JsonPrinter.output_graph g

let diff_to_json g diff =
  JsonPrinter.output_diff g diff
