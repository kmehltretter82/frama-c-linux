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

open Data
module Sy = Syntax
module Md = Markdown
module Js = Yojson.Basic.Util
open Cil_types

let page = Doc.page `Kernel ~title:"Ast Services" ~filename:"ast.md"

(* -------------------------------------------------------------------------- *)
(* --- Compute Ast                                                        --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register ~page
    ~kind:`EXEC ~name:"kernel.ast.compute"
    ~descr:(Md.plain "Ensures that AST is computed")
    ~input:(module Junit) ~output:(module Junit) Ast.compute

(* -------------------------------------------------------------------------- *)
(* ---  Printers                                                          --- *)
(* -------------------------------------------------------------------------- *)

module Marker =
struct

  open Printer_tag

  type index = {
    tags : string Localizable.Hashtbl.t ;
    locs : (string,localizable) Hashtbl.t ;
  }

  let kid = ref 0

  let index () = {
    tags = Localizable.Hashtbl.create 0 ;
    locs = Hashtbl.create 0 ;
  }

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

  let create_tag = function
    | PStmt(_,s) -> Printf.sprintf "#s%d" s.sid
    | PStmtStart(_,s) -> Printf.sprintf "#k%d" s.sid
    | PVDecl(_,_,v) -> Printf.sprintf "#v%d" v.vid
    | PLval _ -> Printf.sprintf "#l%d" (incr kid ; !kid)
    | PExp(_,_,e) -> Printf.sprintf "#e%d" e.eid
    | PTermLval _ -> Printf.sprintf "#t%d" (incr kid ; !kid)
    | PGlobal _ -> Printf.sprintf "#g%d" (incr kid ; !kid)
    | PIP _ -> Printf.sprintf "#p%d" (incr kid ; !kid)

  let create loc =
    let { tags ; locs } = STATE.get () in
    try Localizable.Hashtbl.find tags loc
    with Not_found ->
      let tag = create_tag loc in
      Localizable.Hashtbl.add tags loc tag ;
      Hashtbl.add locs tag loc ;
      tag

  let lookup tag = Hashtbl.find (STATE.get()).locs tag

  type t = localizable
  let syntax = Sy.publish ~page:Data.page ~name:"marker"
      ~synopsis:Sy.ident
      ~descr:(Md.plain "Localizable AST marker \
                        (function, globals, statements, properties, etc.)") ()

  let to_json loc = `String (create loc)
  let of_json js =
    try lookup (Js.to_string js)
    with Not_found -> Data.failure "not a localizable marker"

end

module Printer = Printer_tag.Make(Marker)

(* -------------------------------------------------------------------------- *)
(* --- Ast Data                                                           --- *)
(* -------------------------------------------------------------------------- *)

module Stmt = Data.Collection
    (struct
      type t = stmt
      let syntax = Sy.publish ~page:Data.page ~name:"stmt"
          ~synopsis:Sy.ident
          ~descr:(Md.plain "Code statement identifier") ()
      let to_json st =
        let kf = Kernel_function.find_englobing_kf st in
        Marker.to_json (PStmt(kf,st))
      let of_json js =
        let open Printer_tag in
        match Marker.of_json js with
        | PStmt(_,st) | PStmtStart(_,st) -> st
        | _ -> Data.failure "not a stmt marker"
    end)

module Ki = Data.Collection
    (struct
      type t = kinstr
      let syntax = Sy.union [ Sy.tag "global" ; Stmt.syntax ]
      let to_json = function
        | Kglobal -> `String "global"
        | Kstmt st -> Stmt.to_json st
      let of_json = function
        | `String "global" -> Kglobal
        | js -> Kstmt (Stmt.of_json js)
    end)

module Kf = Data.Collection
    (struct
      type t = kernel_function
      let syntax = Sy.publish ~page:Data.page ~name:"fct-id"
          ~synopsis:Sy.ident
          ~descr:(Md.plain "Function identified by its global name.") ()
      let to_json kf =
        `String (Kernel_function.get_name kf)
      let of_json js =
        let key = Js.to_string js in
        try Globals.Functions.find_by_name key
        with Not_found -> Data.failure "Undefined function '%s'" key
    end)

(* -------------------------------------------------------------------------- *)
(* --- Functions                                                          --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register ~page
    ~kind:`GET ~name:"kernel.ast.getFunctions"
    ~descr:(Md.plain "Collect all functions in the AST")
    ~input:(module Junit) ~output:(module Kf.Jlist)
    begin fun () ->
      let pool = ref [] in
      Globals.Functions.iter (fun kf -> pool := kf :: !pool) ;
      List.rev !pool
    end

let () = Request.register ~page
    ~kind:`GET ~name:"kernel.ast.printFunction"
    ~descr:(Md.plain "Print the AST of a function")
    ~input:(module Kf) ~output:(module Jtext)
    (fun kf -> Jbuffer.to_json Printer.pp_global (Kernel_function.get_global kf))

(* -------------------------------------------------------------------------- *)
(* --- Files                                                              --- *)
(* -------------------------------------------------------------------------- *)

let get_files () =
  let files = Kernel.Files.get () in
  List.map (fun f -> (f:Filepath.Normalized.t:>string)) files

let () =
  Request.register
    ~page
    ~descr:(Md.plain "Get the currently analyzed source file names")
    ~kind:`GET
    ~name:"kernel.ast.getFiles"
    ~input:(module Junit) ~output:(module Jstring.Jlist)
    get_files

let set_files files =
  let s = String.concat "," files in
  Kernel.Files.As_string.set s

let () =
  Request.register
    ~page
    ~descr:(Md.plain "Set the source file names to analyze.")
    ~kind:`SET
    ~name:"kernel.ast.setFiles"
    ~input:(module Jstring.Jlist)
    ~output:(module Junit)
    set_files

let () =
  Request.register
    ~page
    ~descr:(Md.plain "Compute the AST of the currently set source file names.")
    ~kind:`EXEC
    ~name:"kernel.ast.execCompute"
    ~input:(module Junit)
    ~output:(module Junit)
    (fun () ->
       if not (Ast.is_computed ())
       then File.init_from_cmdline ())

(* -------------------------------------------------------------------------- *)
