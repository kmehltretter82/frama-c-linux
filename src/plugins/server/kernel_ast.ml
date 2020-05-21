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

(* The kind of a marker. *)
module MarkerKind = struct
  let t =
    Enum.dictionary ~page ~name:"markerkind" ~title:"Marker kind"
      ~descr:(Md.plain "Marker kind") ()

  let kind name = Enum.tag t ~name ~descr:(Md.plain name) ()
  let expr = kind "expression"
  let lval = kind "lvalue"
  let var = kind "variable"
  let fct = kind "function"
  let decl = kind "declaration"
  let stmt = kind "statement"
  let glob = kind "global"
  let term = kind "term"
  let prop = kind "property"

  let tag =
    let open Printer_tag in
    function
    | PStmt _ -> stmt
    | PStmtStart _ -> stmt
    | PVDecl _ -> decl
    | PLval (_, _, (Var vi, NoOffset)) ->
      if Cil.isFunctionType vi.vtype then fct else var
    | PLval _ -> lval
    | PExp _ -> expr
    | PTermLval _ -> term
    | PGlobal _ -> glob
    | PIP _ -> prop

  let data = Enum.publish t ~tag ()
  include (val data : S with type t = Printer_tag.localizable)
end

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

  let get_name = function
    | PLval (_, _, (Var vi, NoOffset)) -> Some vi.vname
    | PLval (_, _, lval) -> Some (Format.asprintf "%a" Printer.pp_lval lval)
    | PExp  (_, _, expr) -> Some (Format.asprintf "%a" Printer.pp_exp expr)
    | PStmt _ | PStmtStart _ | PVDecl _
    | PTermLval _ | PGlobal _| PIP _ -> None

  let iter f =
    Localizable.Hashtbl.iter (fun key str -> f (key, str)) (STATE.get ()).tags

  let array =
    let model = States.model () in
    let () =
      States.column ~model
        ~name:"kind" ~descr:(Md.plain "Marker kind")
        ~data:(module MarkerKind) ~get:fst ()
    in
    let () =
      States.column ~model
        ~name:"name"
        ~descr:(Md.plain "Marker identifier for the end-user, if any")
        ~data:(module Jstring.Joption)
        ~get:(fun (tag, _) -> get_name tag)
        ()
    in
    States.register_array
      ~page
      ~name:"kernel.ast.markerKind"
      ~descr:(Md.plain "Kind of markers")
      ~key:snd
      ~iter
      model

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
      States.update array (loc, tag);
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


module TypeId =
  Data.Index (Cil_datatype.Typ.Map)
    (struct
      let page = page
      let name = "type"
      let descr = Md.plain "C Type"
    end)

module VarId =
  Data.Identified (Cil_datatype.Varinfo_Id)
    (struct
      let page = page
      let name = "varinfo"
      let descr = Md.plain "Varinfo"
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
(* --- Information                                                        --- *)
(* -------------------------------------------------------------------------- *)

module TypeInfo = struct
  type record

  let record : record Record.signature =
    Record.signature ~page
      ~name:"type" ~descr:(Md.plain "Information about a C type") ()

  let id = Record.field record ~name:"id"
      ~descr:(Md.plain "Type id") (module Jint)
  let name = Record.field record ~name:"name"
      ~descr:(Md.plain "Type name") (module Jstring)
  let size = Record.field record ~name:"size"
      ~descr:(Md.plain "Bit size") (module Jint.Joption)

  module R = (val (Record.publish record) : Record.S with type r = record)

  type t = typ
  let syntax = R.syntax

  let getSize typ =
    try Some (Cil.bitsSizeOf typ)
    with Cil.SizeOfError _ -> None

  let to_json typ =
    R.default |>
    R.set id (TypeId.get typ) |>
    R.set name (Format.asprintf "%a" Printer.pp_typ typ) |>
    R.set size (getSize typ) |>
    R.to_json

  let of_json json =
    let r = R.of_json json in
    try TypeId.find (R.get id r)
    with Not_found -> Data.failure "Unknown type"
end

module VarInfo = struct
  type record

  let record : record Record.signature =
    Record.signature ~page
      ~name:"varinfo" ~descr:(Md.plain "Information about a variable") ()

  let id = Record.field record ~name:"id"
      ~descr:(Md.plain "Variable id") (module Jint)
  let name = Record.field record ~name:"name"
      ~descr:(Md.plain "Variable name") (module Jstring)
  let typ = Record.field record ~name:"type"
      ~descr:(Md.plain "Variable type") (module TypeInfo)
  let fct = Record.field record ~name:"function"
      ~descr:(Md.plain "Is the variable a function?") (module Jbool)
  let global = Record.field record ~name:"global"
      ~descr:(Md.plain "Is the variable global?") (module Jbool)
  let formal = Record.field record ~name:"formal"
      ~descr:(Md.plain "Is the variable formal?") (module Jbool)
  let kf = Record.option record ~name:"defining_function"
      ~descr:(Md.plain "Function defining the variable") (module Kf)
  let addrof = Record.field record ~name:"addrof"
      ~descr:(Md.plain "Is the variable address taken?") (module Jbool)
  let referenced = Record.field record ~name:"referenced"
      ~descr:(Md.plain "Is the variable referenced?") (module Jbool)
  let temp = Record.field record ~name:"temp"
      ~descr:(Md.plain "Is the variable temporary?") (module Jbool)
  let descr = Record.option record ~name:"descr"
      ~descr:(Md.plain "Description of temporary variable") (module Jstring)

  module R = (val (Record.publish record) : Record.S with type r = record)

  type t = varinfo
  let syntax = R.syntax

  let to_json vi =
    R.default |>
    R.set name vi.vname |>
    R.set typ vi.vtype |>
    R.set fct (Cil.isFunctionType vi.vtype) |>
    R.set global vi.vglob |>
    R.set formal vi.vformal |>
    R.set kf (Kernel_function.find_defining_kf vi) |>
    R.set addrof vi.vaddrof |>
    R.set referenced vi.vreferenced |>
    R.set temp vi.vtemp |>
    R.set descr vi.vdescr |>
    R.to_json

  let of_json json =
    let r = R.of_json json in
    try VarId.find (R.get id r)
    with Not_found -> Data.failure "Unknown varinfo"
end

module Info = struct
  type record

  let record : record Record.signature =
    Record.signature ~page ~name:"information"
      ~descr:(Md.plain "Information about an AST marker") ()

  let kind = Record.field record ~name:"kind" ~descr:(Md.plain "Kind")
      (module MarkerKind)
  let typ = Record.option record ~name:"type" ~descr:(Md.plain "Type")
      (module TypeInfo)
  let kf = Record.option record ~name:"function" ~descr:(Md.plain "Function")
      (module Kf)
  let varinfo = Record.option record ~name:"varinfo"
      ~descr:(Md.plain "Varinfo information")
      (module VarInfo)

  module R = (val (Record.publish record) : Record.S with type r = record)

  type t = Printer_tag.localizable
  let syntax = R.syntax

  let to_json (loc: t) =
    R.default |>
    R.set kind loc |>
    R.set typ (Printer_tag.typ_of_localizable loc) |>
    R.set kf (Printer_tag.kf_of_localizable loc) |>
    R.set varinfo (Printer_tag.varinfo_of_localizable loc) |>
    R.to_json
end

let () = Request.register ~page
    ~kind:`GET ~name:"kernel.ast.info"
    ~descr:(Md.plain "Get information about a marker")
    ~input:(module Jstring) ~output:(module Info)
    Marker.lookup

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
