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
open Data
open Dive_types

let page = Doc.page (`Plugin "dive")
    ~title:"Dive general services"
    ~filename:"dive.md"


(* -------------------------------------------------------------------------- *)
(* --- State handling                                                     --- *)
(* -------------------------------------------------------------------------- *)

(* TODO: project state *)
let get_context =
  let context = ref None in
  fun () ->
    match !context with
    | Some c -> c
    | None ->
      let c = Build.create () in
      context := Some c;
      c

let global_window = ref {
    perception = { backward = 2 ; forward = 0 };
    horizon = { backward = None ; forward = None };
  }


(* -------------------------------------------------------------------------- *)
(* --- Data types                                                         --- *)
(* -------------------------------------------------------------------------- *)

let fail js =
  failure_from_type_error "Invalid source format" js


module Range : Data.S with type t = int option range =
struct
  type t = int option range
  let name = "dive-range"
  let descr = Markdown.plain "Parametrization of the exploration range"

  let details = Markdown.([Block [Text [
      Emph "Backward exploration"; Plain " gives the write dependencies while ";
      Emph "forward exploration"; Plain " gives the read dependencies"]]])

  let synopsis = Syntax.record [
      "backward", Jint.Joption.syntax;
      "forward", Jint.Joption.syntax;
    ]

  let syntax = Syntax.publish ~page ~name ~synopsis ~descr ~details ()

  let to_json (r : int option range) =
    `Assoc [
      "backward", Jint.Joption.to_json r.backward ;
      "forward" , Jint.Joption.to_json r.forward ;
    ]

  let of_json js =
    match js with
    | `Assoc assoc ->
      begin try {
        backward = Jint.Joption.of_json (List.assoc "backward" assoc);
        forward = Jint.Joption.of_json (List.assoc "forward" assoc);
      }
        with Not_found -> fail js
      end
    | _ -> fail js
end


module Window : Data.S with type t = window =
struct
  type t = window
  let name = "dive-window"
  let descr = Markdown.plain "Parametrization of the graph exploration."

  let details = Markdown.([Block [Text [
      Plain "The perception is how far dive will explore from root nodes and \
             the horizon is the range beyond which the nodes must be hidden. ";
      Inline_code "perception"; Plain " must be a finite range and ";
      Inline_code "perception.forward"; Plain " is ignored for now."]]])

  let synopsis = Syntax.record [
      "perception", Range.syntax;
      "horizon", Range.syntax;
    ]

  let syntax = Syntax.publish ~page ~name ~synopsis ~descr ~details ()

  let to_json w =
    `Assoc [
      "perception", Range.to_json {
        backward = Some w.perception.backward;
        forward = Some w.perception.forward
      } ;
      "horizon" , Range.to_json w.horizon ;
    ]

  let of_json js =
    match js with
    | `Assoc assoc ->
      begin
        let perception =
          try Range.of_json (List.assoc "perception" assoc)
          with Not_found -> fail js
        and horizon =
          try Range.of_json (List.assoc "horizon" assoc)
          with Not_found -> fail js
        in
        match perception with
        | { forward = None } | { backward = None } -> fail js
        | { backward = Some backward ; forward = Some forward } -> {
            perception = { backward ; forward };
            horizon
          }
      end
    | _ -> fail js
end


module Graph =
struct
  type t = Imprecision_graph.t
  let syntax = Syntax.any
  let to_json = Imprecision_graph.to_json
end


module GraphDiff =
struct
  type t = Imprecision_graph.t * graph_diff
  let syntax = Syntax.any
  let to_json = fun (g,d) -> Imprecision_graph.diff_to_json g d
end


module Node = Data.Collection (struct
    type t = node

    let syntax = Syntax.publish ~page ~name:"dive-node"
        ~synopsis:Syntax.int
        ~descr:(Markdown.plain "A node identifier in the graph") ()

    let to_json node =
      `Int node.node_key

    let of_json json =
      let open Yojson.Basic.Util in
      let node_key = to_int json in
      try
        Build.find_node (get_context ()) node_key
      with Not_found ->
        Data.failure "no node '%d' in the current graph" node_key
  end)


(* -------------------------------------------------------------------------- *)
(* --- Actions                                                            --- *)
(* -------------------------------------------------------------------------- *)

let finalize' context node_opt =
  begin match node_opt with
    | None -> ()
    | Some node ->
      let depth = !global_window.perception.backward
      and horizon = !global_window.horizon in
      Build.explore ~depth context node;
      if Extlib.has_some horizon.forward ||
         Extlib.has_some horizon.backward
      then
        Build.reduce_to_horizon context horizon node
  end;
  Build.get_graph context, Build.take_last_differences context

let finalize context node =
  finalize' context (Some node)

let () = Request.register ~page
    ~kind:`SET ~name:"dive.window"
    ~descr:(Markdown.plain "Set the exploration window")
    ~input:(module Window) ~output:(module Data.Junit)
    (fun window -> global_window := window)

let () = Request.register ~page
    ~kind:`GET ~name:"dive.graph"
    ~descr:(Markdown.plain "Retrieve the whole graph")
    ~input:(module Data.Junit) ~output:(module Graph)
    (fun () -> Build.get_graph (get_context ()))

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.clear"
    ~descr:(Markdown.plain "Erase the graph and start over with an empty one")
    ~input:(module Data.Junit) ~output:(module Data.Junit)
    (fun () -> Build.clear (get_context ()))

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.add_node"
    ~descr:(Markdown.plain "Add a node to the graph")
    ~input:(module Kernel_ast.Marker) ~output:(module GraphDiff)
    begin fun loc ->
      let context = get_context () in
      finalize' context (Build.add_localizable context loc)
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.explore"
    ~descr:(Markdown.plain "Explore the graph starting from an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let context = get_context () in
      finalize context node
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.show"
    ~descr:(Markdown.plain "Show the dependencies of an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let context = get_context () in
      Build.show context node;
      finalize context node
    end

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.hide"
    ~descr:(Markdown.plain "Hide the dependencies of an existing vertex")
    ~input:(module Node) ~output:(module GraphDiff)
    begin fun node ->
      let context = get_context () in
      Build.hide_and_reduce context node;
      finalize' context None
    end
