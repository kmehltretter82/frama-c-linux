(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `IIG'.                       *)
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

type vertex_label = {
  vertex_key : int;
  vertex_lval : Cil_types.lval
}

type dependency_kind = Callee | Data | Adress | Control

type edge_label = {
  edge_key : int;
  edge_kind : dependency_kind;
}

let dummy_edge = {
  edge_key = -1;
  edge_kind = Data;
}

module Vertex =
struct
  type t = vertex_label
  let compare v1 v2 = v1.vertex_key - v2.vertex_key
  let hash v = v.vertex_key
  let equal v1 v2 = v1.vertex_key = v2.vertex_key
end

module Edge =
struct
  type t = edge_label
  let compare e1 e2 = e1.edge_key - e2.edge_key
  let hash e = e.edge_key
  let equal e1 e2 = e1.edge_key = e2.edge_key
  let default = dummy_edge
end

module G = Graph.Imperative.Digraph.ConcreteBidirectionalLabeled (Vertex) (Edge)
include G

let lval_proprietary_kf lval =
  match lval with
  | Cil_types.Var vi, Cil_types.NoOffset ->
    Kernel_function.find_defining_kf vi
  | _ -> None

let ouptput_to_dot out_channel g =
  let open Graph.Graphviz.DotAttributes in

  let label s = `HtmlLabel (Extlib.html_escape s) in

  let module Table = Kernel_function.Hashtbl in
  let table = Table.create 13 in
  let build_subgraph kf = {
    sg_name = "f" ^ (string_of_int (Kernel_function.get_id kf));
    sg_attributes = [label (Kernel_function.get_name kf) ];
    sg_parent = None;
  }
  in

  let module Dot = Graph.Graphviz.Dot (
    struct
      include G
      let graph_attributes _g = []
      let default_vertex_attributes _g = [`Shape `Box]
      let vertex_name v = "cp" ^ (string_of_int v.vertex_key)
      let vertex_label v =
        Pretty_utils.to_string Cil_printer.pp_lval v.vertex_lval
      let vertex_attributes v = [ label (vertex_label v) ]
      let get_subgraph v =
        let kf = lval_proprietary_kf v.vertex_lval in
        Extlib.opt_map (fun kf -> Table.memo table kf build_subgraph) kf
      let default_edge_attributes _g = []
      let edge_attributes (_v1,e,_v2) =
        match e.edge_kind with
        | Callee -> [`Color 0xff0000 ]
        | _ -> []
    end)
  in
  Dot.output_graph out_channel g
