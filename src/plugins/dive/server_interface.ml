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

let package = Package.package ~plugin:"dive" ~title:"Dive Services" ()

module Graph =
struct
  type t = Imprecision_graph.t
  let jtype = Data.Jany.jtype
  let to_json = Imprecision_graph.to_json
end

module GraphDiff =
struct
  type t = Imprecision_graph.t * Graph_types.graph_diff
  let jtype = Data.Jany.jtype
  let to_json = fun (g,d) -> Imprecision_graph.diff_to_json g d
end

module Variable =
struct
  let name = "variableName"
  let descr = Markdown.plain "The name of variable of the program"

  let signature = Data.Record.signature ()

  let fun_field = Data.Record.option signature
      ~name:"funName"
      ~descr:(Markdown.plain "owner function for a local variable")
      (module Data.Jalpha)

  let var_field = Data.Record.field signature
      ~name:"varName"
      ~descr:(Markdown.plain "variable name")
      (module Data.Jalpha)

  type t = Cil_types.varinfo

  let data = Data.Record.publish ~package ~name ~descr signature
  module R = (val data : Data.Record.S with type r = t)

  let jtype = R.jtype

  let to_json v =
    let varname = v.Cil_types.vname in
    let fields = R.default |> R.set var_field varname in
    let fields = match Kernel_function.find_defining_kf v with
      | Some kf -> fields |> R.set fun_field (Some (Kernel_function.get_name kf))
      | None -> fields
    in
    R.to_json fields

  let of_json json =
    let open Yojson.Basic.Util in
    let funname =
      try Some (json |> member "fun" |> to_string)
      with Not_found -> None
    and varname = json |> member "var" |> to_string in
    match funname with
    | Some name ->
      let kf =
        try
          Globals.Functions.find_by_name name
        with Not_found ->
          Data.failure "no function '%s'" name
      in
      let vi =
        try Globals.Vars.find_from_astinfo varname (Cil_types.VLocal kf)
        with Not_found ->
        try Globals.Vars.find_from_astinfo varname (Cil_types.VFormal kf)
        with Not_found ->
          Data.failure "no variable '%s' in function '%s'"
            varname name
      in
      vi
    | None ->
      match
        Globals.Syntactic_search.find_in_scope varname Cil_types.Program
      with
      | Some vi -> vi
      | None ->
        Data.failure "no global variable '%s'" varname
end

module Node : Data.S with type t = Graph_types.node =
struct
  type t = Graph_types.node

  let jtype = Package.Jindex "dive-node"

  let to_json node =
    `Int node.Graph_types.node_key

  let of_json json =
    let open Yojson.Basic.Util in
    let node_key = to_int json in
    try
      Build.find_node (get_graph ()) node_key
    with Not_found ->
      Data.failure "no node '%d' in the current graph" node_key
end

let () = Request.register ~package
    ~kind:`GET ~name:"graph"
    ~descr:(Markdown.plain "Retrieve the whole graph")
    ~input:(module Data.Junit) ~output:(module Graph)
    (fun () -> Build.get_graph (get_graph ()))

let () = Request.register ~package
    ~kind:`EXEC ~name:"clear"
    ~descr:(Markdown.plain "Erase the graph and start over with an empty one")
    ~input:(module Data.Junit) ~output:(module Data.Junit)
    (fun () -> Build.clear (get_graph ()))

let () = Request.register ~package
    ~kind:`EXEC ~name:"addVar"
    ~descr:(Markdown.plain "Add a variable to the graph")
    ~input:(module Variable) ~output:(module GraphDiff)
    begin fun var ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.add_var ~depth g var;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~package
    ~kind:`EXEC ~name:"addFunctionAlarms"
    ~descr:(Markdown.plain "Add all alarms of the given function")
    ~input:(module Kernel_ast.Kf) ~output:(module GraphDiff)
    begin fun kf ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.add_function_alarms ~depth g kf;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~package
    ~kind:`EXEC ~name:"explore"
    ~descr:(Markdown.plain "Explore the graph starting from an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.explore_from_node ~depth g node;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~package
    ~kind:`EXEC ~name:"show"
    ~descr:(Markdown.plain "Show the dependencies of an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.show ~depth g node;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~package
    ~kind:`EXEC ~name:"hide"
    ~descr:(Markdown.plain "Hide the dependencies of an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let g = get_graph () in
      Build.hide g node;
      Build.get_graph g, Build.take_last_differences g
    end
