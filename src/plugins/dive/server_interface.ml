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

module Variable = Data.Collection (struct
    module Info = struct
      let page = page
      let name = "dive-variable-name"
      let descr = Markdown.rm "The name of variable of the program"
    end

    module R = Data.Record (Info)

    type t = Cil_types.varinfo

    let syntax = R.syntax

    let _fun_field = R.option "fun"
        ~descr:(Markdown.rm "owner function for a local variable")
        (module Data.Jstring)

    let _var_field = R.field "var"
        ~descr:(Markdown.rm "variable name")
        (module Data.Jstring)

    let to_json v =
      let varname = v.Cil_types.vname in
      let fields =  [ "var", `String varname ] in
      let fields = match Kernel_function.find_defining_kf v with
        | Some kf -> ("fun", `String (Kernel_function.get_name kf)) :: fields
        | None -> fields
      in
      `Assoc fields

    let of_json json =
      let open Yojson.Basic.Util in
      try
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
              Data.failure json "no function '%s'" name
          in
          let vi = 
            try Globals.Vars.find_from_astinfo varname (Cil_types.VLocal kf)
            with Not_found ->
            try Globals.Vars.find_from_astinfo varname (Cil_types.VFormal kf)
            with Not_found ->
              Data.failure json "no variable '%s' in function '%s'"
                varname name
          in
          vi
        | None ->
          match
            Globals.Syntactic_search.find_in_scope varname Cil_types.Program
          with
          | Some vi -> vi
          | None ->
            Data.failure json "no global variable '%s'" varname
      with Not_found | Failure _ ->
        Data.failure json "Invalid source format"
  end)

module Function = Data.Collection (struct
    type t = Cil_types.kernel_function

    let syntax = Syntax.publish ~page ~name:"dive-function-name"
        ~synopsis:Syntax.string
        ~descr:(Markdown.rm "The name of a function of the program") ()

    let to_json kf =
      `String (Kernel_function.get_name kf)

    let of_json json =
      let open Yojson.Basic.Util in
      let name = to_string json in
      try
        Globals.Functions.find_by_name name
      with Not_found ->
        Data.failure json "no function '%s'" name
  end)

module Node = Data.Collection (struct
    type t = Graph_types.node

    let syntax = Syntax.publish ~page ~name:"dive-node"
        ~synopsis:Syntax.int
        ~descr:(Markdown.rm "A node identifier in the graph") ()

    let to_json node =
      `Int node.Graph_types.node_key

    let of_json json =
      let open Yojson.Basic.Util in
      let node_key = to_int json in
      try
        Build.find_node (get_graph ()) node_key
      with Not_found ->
        Data.failure json "no node '%d' in the current graph" node_key
  end)


let () = Request.register ~page
    ~kind:`GET ~name:"dive.graph"
    ~descr:(Markdown.rm "Retrieve the whole graph")
    ~input:(module Data.Junit) ~output:(module Graph)
    (fun () -> Build.get_graph (get_graph ()))

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.clear"
    ~descr:(Markdown.rm "Erase the graph and start over with an empty one")
    ~input:(module Data.Junit) ~output:(module Data.Junit)
    (fun () -> Build.clear (get_graph ()))

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.add_var"
    ~descr:(Markdown.rm "Add a variable to the graph")
    ~input:(module Variable) ~output:(module GraphDiff)
    begin fun var ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.add_var ~depth g var;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.add_function_alarms"
    ~descr:(Markdown.rm "Add all alarms of the given function")
    ~input:(module Function) ~output:(module GraphDiff)
    begin fun kf ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.add_function_alarms ~depth g kf;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.explore"
    ~descr:(Markdown.rm "Explore the graph starting from an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.explore_from_node ~depth g node;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.show"
    ~descr:(Markdown.rm "Show the dependencies of an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.show ~depth g node;
      Build.get_graph g, Build.take_last_differences g
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.hide"
    ~descr:(Markdown.rm "Hide the dependencies of an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let g = get_graph () in
      Build.hide g node;
      Build.get_graph g, Build.take_last_differences g
    end