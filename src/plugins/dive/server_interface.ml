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


let page = Doc.page (`Plugin "Dive")
    ~title:"Dive into dependency graph"
    ~filename:"dive.md"

module Graph =
struct
  type t = Imprecision_graph.t
  let syntax = Syntax.any
  let to_json = Imprecision_graph.to_json
end

module Variable = Data.Collection (struct
    type t = Cil_types.varinfo
    let syntax = Syntax.publish ~page ~name:"variable"
        ~synopsis:(Syntax.record [
            "fun", Syntax.option Syntax.string ;
            "var", Syntax.string ])
        ~descr:(Markdown.rm "Variable from the program") ()

    let to_json v =
      let varname = v.Cil_types.vname in
      let fields =  [ "var" , `String varname ] in
      let fields = match Kernel_function.find_defining_kf v with
        | Some kf -> ("fun", `String (Kernel_function.get_name kf)) :: fields
        | None -> fields
      in
      `Assoc fields

    let of_json json =
      try
        let funname =
          try Some (Json.(string (field "fun" json)))
          with Not_found -> None
        and varname = Json.(string (field "var" json)) in
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


let () = Request.register ~page
    ~kind:`GET ~name:"dive.graph"
    ~descr:(Markdown.rm "Retrieve the whole graph")
    ~input:(module Data.Junit) ~output:(module Graph)
    (fun () -> Build.get_graph (get_graph ()))

let () = Request.register ~page
    ~kind:`EXEC ~name:"dive.add_var"
    ~descr:(Markdown.rm "Add a variable to the graph")
    ~input:(module Variable) ~output:(module Graph)
    begin fun var ->
      let depth = Self.DepthLimit.get () in
      let g = get_graph () in
      Build.add_var ~depth g var;
      Build.get_graph g
    end

