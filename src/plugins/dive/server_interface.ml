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

open Server
open Data
open Dive_types

let package = Package.package ~plugin:"dive" ~title:"Dive Services" ()

module Enum () =
struct
  include Enum
  let dictionary = Enum.dictionary ()
  let tag name descr =
    Enum.tag ~name ~descr:(Markdown.plain descr) dictionary
end


(* -------------------------------------------------------------------------- *)
(* --- Data types                                                         --- *)
(* -------------------------------------------------------------------------- *)

module Range : Data.S with type t = int option range =
struct
  type t = int option range
  let name = "range"
  let descr = Markdown.plain "Parametrization of the exploration range."
  let sign : t Record.signature = Record.signature ()

  module Fields =
  struct
    let backward = Record.option sign
        ~name:"backward"
        ~descr:(Markdown.plain "range for the write dependencies")
        (module (Jint))

    let forward = Record.option sign
        ~name:"forward"
        ~descr:(Markdown.plain "range for the read dependencies")
        (module (Jint))
  end

  module Record = (val Record.publish ~package ~name ~descr sign)

  let jtype = Record.jtype

  let to_json r =
    Record.default |>
    Record.set Fields.backward r.backward |>
    Record.set Fields.forward r.forward |>
    Record.to_json

  let of_json js =
    let r = Record.of_json js in
    {
      backward = Record.get Fields.backward r;
      forward = Record.get Fields.forward r;
    }
end


module Window : Data.S with type t = window =
struct
  type t = window
  let name = "explorationWindow"
  let descr = Markdown.plain "Global parametrization of the exploration."
  let sign : t Record.signature = Record.signature ()

  module Fields =
  struct
    let perception = Record.field sign
        ~name:"perception"
        ~descr:(Markdown.plain "how far dive will explore from root nodes ; \
                                must be a finite range")
        (module Range)

    let horizon = Record.field sign
        ~name:"horizon"
        ~descr:(Markdown.plain "range beyond which the nodes must be hidden")
        (module Range)
  end

  module Record = (val Record.publish ~package ~name ~descr sign)

  let jtype = Record.jtype

  let to_json w =
    Record.default |>
    Record.set Fields.perception w.perception |>
    Record.set Fields.horizon w.horizon |>
    Record.to_json

  let of_json js =
    let r = Record.of_json js in
    {
      perception = Record.get Fields.perception r;
      horizon = Record.get Fields.horizon r;
    }
end


module NodeId =
struct
  type t = node
  let name = "nodeId"
  let descr = Markdown.plain "A node identifier in the graph"

  let jtype = Data.declare ~package ~name ~descr Data.Jint.jtype

  let to_json node =
    `Int node.node_key
end

module Callsite =
struct
  let name = "callsite"
  let descr = Markdown.plain "A callsite"
  let jtype = Data.declare ~package ~name ~descr (Jrecord [
      "fun", Jstring;
      "instr", Junion [ Jnumber ; Jtag "global" ];
    ])
end

module Callstack =
struct
  let name = "callstack"
  let descr = Markdown.plain "The callstack context for a node"
  let jtype = Data.declare ~package ~name ~descr (Jarray Callsite.jtype)
end

module NodeLocality =
struct
  let name = "nodeLocality"
  let descr = Markdown.plain "The description of a node locality"
  let jtype = Data.declare ~package ~name ~descr (Jrecord [
      "file", Jstring;
      "callstack", Joption (Callstack.jtype)
    ])
end

module NodeKind = struct
  include Enum ()

  let _tags = [
    tag "scalar" "a single memory cell";
    tag "composite" "a memory bloc containing cells";
    tag "scattered" "a set of memory locations designated by an lvalue";
    tag "unknown" "an unresolved memory location";
    tag "alarm" "an alarm emitted by Frama-C";
    tag "absolute" "a memory location designated by a range of adresses";
    tag "string" "a string literal";
    tag "error" "a placeholder node when an error prevented the generation\
                 process";
    tag "const" "a numeric constant literal";
  ]

  let data = Request.dictionary ~package ~name:"nodeKind"
      ~descr:(Markdown.plain "The nature of a node.") dictionary

  include (val data : Data.S with type t = unit)
end

module Taint = struct
  include Enum ()

  let _tags = [
    tag "direct" "tainted by data";
    tag "indirect" "tainted by control";
    tag "untainted" "not tainted by anything";
  ]

  let data = Request.dictionary ~package ~name:"taint"
      ~descr:(Markdown.plain "Taint of a memory location.") dictionary

  include (val data : Data.S with type t = unit)
end

module Computation = struct
  include Enum ()

  let _tags = [
    tag "no" "dependencies have not been computed";
    tag "partial" "some dependencies have been exploreread/tainted by control";
    tag "yes" "all dependencies have been computed";
  ]

  let data = Request.dictionary ~package ~name:"exploration"
      ~descr:(Markdown.plain
                "The computation state of a node read or write dependencies.")
      dictionary

  include (val data : Data.S with type t = unit)
end

module NodeRange = struct
  include Enum ()

  let _tags = [
    tag "empty" "no value ever computed for this node";
    tag "singleton" "this node can only have one value";
    tag "wide" "this node can take almost all values of its type";
  ]

  let data = Request.dictionary ~package ~name:"nodeRange"
      ~descr:(Markdown.plain "A qualitative description of the range of values \
                              that this node can take.")
      dictionary

  include (val data : Data.S with type t = unit)
end

module Node =
struct
  let name = "node"
  let descr = Markdown.plain "A graph node"
  let jtype = Data.declare ~package ~name ~descr (Jrecord [
      "id", NodeId.jtype;
      "label", Jstring;
      "nkind", NodeKind.jtype;
      "locality", NodeLocality.jtype;
      "is_root", Jboolean;
      "backward_explored", Computation.jtype;
      "forward_explored", Computation.jtype;
      "writes", Jarray Kernel_ast.Location.jtype;
      "values", Joption Jstring;
      "range", Junion [ Jnumber ; NodeRange.jtype ];
      "type", Joption Jstring;
      "taint", Joption Taint.jtype;
    ])
end

module Dependency =
struct
  let name = "dependency"
  let descr = Markdown.plain "The dependency between two nodes"
  let jtype = Data.declare ~package ~name ~descr (Jrecord [
      "id", Jnumber ;
      "src", NodeId.jtype ;
      "dst", NodeId.jtype ;
      "dkind", Jstring ;
      "origins", Jarray Kernel_ast.Location.jtype
    ])
end

module Element =
struct
  type t = Context.element = Node of node | Edge of (node * dependency * node)
  let name = "element"
  let descr = Markdown.plain "A graph element, either a node or a dependency"
  let jtype = Data.declare ~package ~name ~descr
      (Junion [Node.jtype ; Dependency.jtype])

  let to_json = function
    | Context.Node v -> Dive_graph.JsonPrinter.output_node v
    | Edge edge -> Dive_graph.JsonPrinter.output_dep edge
end



(* -------------------------------------------------------------------------- *)
(* --- State handling                                                     --- *)
(* -------------------------------------------------------------------------- *)

let global_window = ref {
    perception = { backward = Some 2 ; forward = Some 1 };
    horizon = { backward = None ; forward = None };
  }

let get_context = (* TODO: projectify ? *)
  let context = Context.create () in
  fun () ->
    if Eva.Analysis.is_computed () then
      context
    else
      Server.Data.failure "Eva analysis not computed"


module Graph =
struct
  let name = "graph"
  let model = States.model ()
  let descr = Markdown.plain "The graph being built as a set of vertices and \
                              edges"

  let key = function
    | Element.Node v -> Format.sprintf "n%d" v.node_key
    | Edge (_,dep,_) -> Format.sprintf "d%d" dep.dependency_key

  let () = States.column model ~name:"element"
      ~descr:(Markdown.plain "a graph element")
      ~data:(module Element)
      ~get:(fun el -> el)

  let iter f =
    let context = get_context () in
    let graph = Context.get_graph context in
    Dive_graph.output_to_json stdout graph;
    Dive_graph.iter_vertex (fun v -> f (Element.Node v)) graph;
    Dive_graph.iter_edges_e (fun e -> f (Element.Edge e)) graph

  let _array =
    let hook f =
      fun g -> f (get_context ()) g
    in
    States.register_array ~package ~name ~descr ~key ~iter model
      ~add_update_hook:(hook Context.set_update_hook)
      ~add_remove_hook:(hook Context.set_remove_hook)
      ~add_reload_hook:(hook Context.set_clear_hook)
end


module NodeId' =
struct
  include NodeId

  let of_json json =
    let node_key = Data.Jint.of_json json in
    try
      Context.find_node (get_context ()) node_key
    with Not_found ->
      Data.failure "no node '%d' in the current graph" node_key
end


(* -------------------------------------------------------------------------- *)
(* --- Actions                                                            --- *)
(* -------------------------------------------------------------------------- *)

let finalize' context = function
  | None -> ()
  | Some node ->
    let may_explore f =
      Option.iter (fun depth -> f ~depth context node)
    in
    may_explore Build.explore_backward !global_window.perception.backward;
    may_explore Build.explore_forward !global_window.perception.forward;
    let horizon = !global_window.horizon in
    if Option.is_some horizon.forward ||
       Option.is_some horizon.backward
    then
      Build.reduce_to_horizon context horizon node

let finalize context node =
  finalize' context (Some node)

let () = Request.register ~package
    ~kind:`SET ~name:"window"
    ~descr:(Markdown.plain "Set the exploration window")
    ~input:(module Window) ~output:(module Data.Junit)
    (fun window -> global_window := window)

let () = Request.register ~package
    ~kind:`EXEC ~name:"clear"
    ~descr:(Markdown.plain "Erase the graph and start over with an empty one")
    ~input:(module Data.Junit) ~output:(module Data.Junit)
    (fun () -> Context.clear (get_context ()))

let () = Request.register ~package
    ~kind:`EXEC ~name:"add"
    ~descr:(Markdown.plain "Add a node to the graph")
    ~input:(module Kernel_ast.Marker) ~output:(module Joption (NodeId'))
    begin fun loc ->
      let context = get_context () in
      let node = Build.add_localizable context loc in
      finalize' context node;
      node
    end

let () = Request.register ~package
    ~kind:`EXEC ~name:"explore"
    ~descr:(Markdown.plain "Explore the graph starting from an existing vertex")
    ~input:(module NodeId') ~output:(module Data.Junit)
    begin fun node ->
      let context = get_context () in
      Build.show context node;
      finalize context node
    end

let () = Request.register ~package
    ~kind:`EXEC ~name:"show"
    ~descr:(Markdown.plain "Show the dependencies of an existing vertex")
    ~input:(module NodeId') ~output:(module Data.Junit)
    begin fun node ->
      let context = get_context () in
      Build.show context node;
      Build.explore_backward ~depth:1 context node;
      finalize' context None
    end

let () = Request.register ~package
    ~kind:`EXEC ~name:"hide"
    ~descr:(Markdown.plain "Hide the dependencies of an existing vertex")
    ~input:(module NodeId') ~output:(module Data.Junit)
    begin fun node ->
      let context = get_context () in
      Build.hide context node;
      finalize' context None
    end
