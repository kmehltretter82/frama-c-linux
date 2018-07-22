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

open Dependency_types

type vertex_label = {
  vertex_key : int;
  vertex_location : symbolic_location;
  mutable vertex_imprecise_data : bool;
}

type edge_label = {
  edge_key : int;
  edge_kind : dependency_kind;
  mutable edge_folded : bool;
}

let dummy_edge = {
  edge_key = -1;
  edge_kind = Data;
  edge_folded = false;
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

let vertex_count = ref 0
let edge_count = ref 0

let create_vertex g vertex_location =
  let v = {
    vertex_key = !vertex_count;
    vertex_location;
    vertex_imprecise_data = false;
  }
  in
  incr vertex_count;
  add_vertex g v;
  v

let create_edge ~allow_folding g v1 edge_kind v2 =
  try
    try
      if allow_folding then
        let _,e,_ = G.find_edge g v1 v2 in
        if e.edge_kind = edge_kind then begin
          e.edge_folded <- true;
          raise Exit;
        end;
    with Not_found -> ();
    let e = {
      edge_key = !edge_count;
      edge_kind;
      edge_folded = false;
    }
    in
    incr edge_count;
    add_edge_e g (v1,e,v2)
  with Exit -> ()


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
      let default_vertex_attributes _g = []
      let vertex_name v = "cp" ^ (string_of_int v.vertex_key)
      let vertex_label v =
        Pretty_utils.to_string Cil_printer.pp_lval v.vertex_location.sl_lval
      let vertex_attributes v =
        let shape = match v.vertex_location.sl_kind with
        | Precise -> [`Shape `Box]
        | Imprecise -> [ `Shape `Parallelogram ]
        | Folded -> [ `Shape `Box3d ]
        in
        let l = ref ([ label (vertex_label v) ] @ shape) in
        if v.vertex_imprecise_data then
          l := [ `Color 0xff0000 ; `Style `Bold ;
                 `Style `Filled ; `Fillcolor 0xffbbbb ] @ !l;
        !l
      let get_subgraph v =
        let kf = v.vertex_location.sl_owner in
        Extlib.opt_map (fun kf -> Table.memo table kf build_subgraph) kf
      let default_edge_attributes _g = []
      let edge_attributes (_v1,e,_v2) =
        let kind_attribute = match e.edge_kind with
          | Callee -> [`Color 0xff0000 ]
          | _ -> []
        and folding_attribute = match e.edge_folded with
          | true -> [ `Style `Bold ]
          | false -> []
        in kind_attribute @ folding_attribute 
    end)
  in
  Dot.output_graph out_channel g
