(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

open Server

(* TODO: state *)
let get_graph =
  let graph = ref None in
  fun () ->
    match !graph with
    | Some g -> g
    | None ->
      let g = Build.create () in
      graph := Some g;
      g


let page = Doc.page (`Plugin "dive")
    ~title:"Dive Services"
    ~filename:"dive.md"

module Graph =
struct
  type t = Imprecision_graph.t
  let syntax = Syntax.any
  let to_json = Imprecision_graph.to_json
end

module GraphDiff =
struct
  type t = Imprecision_graph.t * Graph_types.graph_diff
  let syntax = Syntax.any
  let to_json = fun (g,d) -> Imprecision_graph.diff_to_json g d
end

module Node = Data.Collection (struct
    type t = Graph_types.node

    let syntax = Syntax.publish ~page ~name:"dive-node"
        ~synopsis:Syntax.int
        ~descr:(Markdown.plain "A node identifier in the graph") ()

    let to_json node =
      `Int node.Graph_types.node_key

    let of_json json =
      let open Yojson.Basic.Util in
      let node_key = to_int json in
      try
        Build.find_node (get_graph ()) node_key
      with Not_found ->
        Data.failure "no node '%d' in the current graph" node_key
  end)


let () = Request.register ~page
    ~kind:`GET ~name:"dive.graph"
    ~descr:(Markdown.plain "Retrieve the whole graph")
    ~input:(module Data.Junit) ~output:(module Graph)
    (fun () -> Build.get_graph (get_graph ()))

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.clear"
    ~descr:(Markdown.plain "Erase the graph and start over with an empty one")
    ~input:(module Data.Junit) ~output:(module Data.Junit)
    (fun () -> Build.clear (get_graph ()))

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.add_node"
    ~descr:(Markdown.plain "Add a node to the graph")
    ~input:(module Kernel_ast.Marker) ~output:(module GraphDiff)
    begin fun loc ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.add_localizable ~depth g loc;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.explore"
    ~descr:(Markdown.plain "Explore the graph starting from an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.explore_from_node ~depth g node;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.show"
    ~descr:(Markdown.plain "Show the dependencies of an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.show ~depth g node;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.hide"
    ~descr:(Markdown.plain "Hide the dependencies of an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let g = get_graph () in
      Build.hide g node;
      Build.get_graph g, Build.take_last_differences g
    end
