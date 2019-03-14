(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
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

open Cil_types
open Data
module Jutil = Yojson.Basic.Util

(* -------------------------------------------------------------------------- *)
(* --- Frama-C Ast Services                                               --- *)
(* -------------------------------------------------------------------------- *)

let ast_page =
  Doc.page `Kernel ~title:"Ast Services" ~filename:"ast.md"

module ExecCompute = Request.Register(Junit)(Junit)
    (struct
      let kind = `EXEC
      let name = "Kernel.Ast.ExecCompute"
      let descr = Markdown.rm "Ensures that AST is computed"
      let page = ast_page
      let details = []
      type input = unit
      type output = unit
      let process = Ast.compute
    end)

(* -------------------------------------------------------------------------- *)
(* ---  Printers                                                          --- *)
(* -------------------------------------------------------------------------- *)

module Tag =
struct

  open Printer_tag

  type index = (string,localizable) Hashtbl.t

  let kid = ref 0

  let index () = Hashtbl.create 0

  module TYPE : Datatype.S with type t = index =
    Datatype.Make
      (struct
        type t = index
        include Datatype.Undefined
        let reprs = [index()]
        let name = "Server.Jprinter.Index"
        let mem_project = Datatype.never_any_project
      end)

  module STATE = State_builder.Ref(TYPE)
      (struct
        let name = "Server.Jprinter.State"
        let dependencies = []
        let default = index
      end)

  let of_stmt s = Printf.sprintf "#s%d" s.sid
  let of_start s = Printf.sprintf "#k%d" s.sid
  let of_varinfo v = Printf.sprintf "#v%d" v.vid

  let create_tag = function
    | PStmt(_,st) -> of_stmt st
    | PStmtStart(_,st) -> of_start st
    | PVDecl(_,_,vi) -> of_varinfo vi
    | PLval _ -> Printf.sprintf "#l%d" (incr kid ; !kid)
    | PExp _ -> Printf.sprintf "#e%d" (incr kid ; !kid)
    | PTermLval _ -> Printf.sprintf "#t%d" (incr kid ; !kid)
    | PGlobal _ -> Printf.sprintf "#g%d" (incr kid ; !kid)
    | PIP _ -> Printf.sprintf "#p%d" (incr kid ; !kid)

  let create item =
    let tag = create_tag item in
    let index = STATE.get () in
    Hashtbl.add index tag item ; tag

  let lookup = Hashtbl.find (STATE.get())

end

module PP = Printer_tag.Make(Tag)

(* -------------------------------------------------------------------------- *)
(* --- Ast Data                                                           --- *)
(* -------------------------------------------------------------------------- *)

module Stmt = Data.Collection
    (struct
      type t = stmt
      let syntax = Syntax.publish ast_page
          ~name:"stmt"
          ~synopsis:Syntax.ident
          ~descr:(Markdown.praw "Code statement identifier")
      let to_json st = `String (Tag.of_stmt st)
      let of_json js =
        try
          let open Printer_tag in
          match Tag.lookup (Jutil.to_string js) with
          | PStmt(_,st) -> st
          | _ -> raise Not_found
        with Not_found ->
          Data.failure "Unknown stmt id" js
    end)

module Ki = Data.Collection
    (struct
      type t = kinstr
      let syntax = Syntax.union [ Syntax.tag "global" ; Stmt.syntax ]
      let to_json = function
        | Kglobal -> `String "global"
        | Kstmt st -> `String (Tag.of_stmt st)
      let of_json = function
        | `String "global" -> Kglobal
        | js -> Kstmt (Stmt.of_json js)
    end)

module Kf = Data.Collection
    (struct
      type t = kernel_function
      let syntax = Syntax.publish ast_page
          ~name:"function"
          ~synopsis:Syntax.ident
          ~descr:(Markdown.praw "Function, identified by its global name.")
      let to_json kf = `String (Kernel_function.get_name kf)
      let of_json js =
        try Jutil.to_string js |> Globals.Functions.find_by_name
        with Not_found -> Data.failure "Undefined function" js
    end)

(* -------------------------------------------------------------------------- *)
(* --- Functions                                                          --- *)
(* -------------------------------------------------------------------------- *)

module GetFunctions = Request.Register(Junit)(Kf.Jlist)
    (struct
      let kind = `GET
      let name = "Kernel.Ast.GetFunctions"
      let descr = Markdown.rm "Collect all functions in the AST"
      let page = ast_page
      let details = []
      type input = unit
      type output = kernel_function list
      let process () =
        let pool = ref [] in
        Globals.Functions.iter (fun kf -> pool := kf :: !pool) ;
        List.rev !pool
    end)

module PrintFunction = Request.Register(Kf)(Jtext)
    (struct
      let kind = `GET
      let name = "Kernel.Ast.PrintFunction"
      let descr = Markdown.rm "Print the AST of a function"
      let page = ast_page
      let details = []
      type input = kernel_function
      type output = json
      let process kf =
        Jbuffer.to_json PP.pp_global (Kernel_function.get_global kf)
    end)

(* -------------------------------------------------------------------------- *)
