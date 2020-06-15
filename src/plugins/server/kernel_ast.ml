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
        ~descr:(Md.plain "Marker short name")
        ~data:(module Jstring)
        ~get:(fun (tag, _) -> Printer_tag.label tag)
        ()
    in
    let () =
      States.column ~model
        ~name:"descr"
        ~descr:(Md.plain "Marker declaration or description")
        ~data:(module Jstring)
        ~get:(fun (tag, _) -> Rich_text.to_string Printer_tag.pretty tag)
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

(* -------------------------------------------------------------------------- *)
(* --- Functions                                                          --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register ~page
    ~kind:`GET ~name:"kernel.ast.printFunction"
    ~descr:(Md.plain "Print the AST of a function")
    ~input:(module Kf) ~output:(module Jtext)
    (fun kf -> Jbuffer.to_json Printer.pp_global (Kernel_function.get_global kf))

module Functions =
struct

  let key kf = Printf.sprintf "kf#%d" (Kernel_function.get_id kf)

  let signature kf =
    let global = Kernel_function.get_global kf in
    Rich_text.to_string Printer_tag.pretty (PGlobal global)

  let array : kernel_function States.array =
    begin
      let model = States.model () in
      States.column ~model
        ~name:"name"
        ~descr:(Md.plain "Name")
        ~data:(module Data.Jstring)
        ~get:Kernel_function.get_name () ;
      States.column ~model
        ~name:"signature"
        ~descr:(Md.plain "Signature")
        ~data:(module Data.Jstring)
        ~get:signature
        () ;
      States.register_array
        ~page ~key
        ~name:"kernel.ast.functions"
        ~descr:(Md.plain "AST Functions")
        ~iter:Globals.Functions.iter
        ~add_reload_hook:Ast.add_hook_on_update
        model
    end

end

(* -------------------------------------------------------------------------- *)
(* --- Information                                                        --- *)
(* -------------------------------------------------------------------------- *)

module Info = struct
  open Printer_tag

  let print_function fmt name =
    let stag = Transitioning.Format.stag_of_string name in
    Transitioning.Format.pp_open_stag fmt stag;
    Format.pp_print_string fmt name;
    Transitioning.Format.pp_close_stag fmt ()

  let print_kf fmt kf = print_function fmt (Kernel_function.get_name kf)

  let print_variable fmt vi =
    Format.fprintf fmt "Variable %s has type %a.@."
      vi.vname Printer.pp_typ vi.vtype;
    let kf = Kernel_function.find_defining_kf vi in
    let pp_kf fmt kf = Format.fprintf fmt " of function %a" print_kf kf in
    Format.fprintf fmt "It is a %s variable%a.@."
      (if vi.vglob then "global" else if vi.vformal then "formal" else "local")
      (Transitioning.Format.pp_print_option pp_kf) kf;
    if vi.vtemp then
      Format.fprintf fmt "This is a temporary variable%s.@."
        (match vi.vdescr with None -> "" | Some descr -> " for " ^ descr);
    Format.fprintf fmt "It is %sreferenced and its address is %staken."
      (if vi.vreferenced then "" else "not ")
      (if vi.vaddrof then "" else "not ")

  let print_varinfo fmt vi =
    if Cil.isFunctionType vi.vtype
    then
      Format.fprintf fmt "%a is a C function of type '%a'."
        print_function vi.vname Printer.pp_typ vi.vtype
    else print_variable fmt vi

  let print_lvalue fmt _loc = function
    | Var vi, NoOffset -> print_varinfo fmt vi
    | lval ->
      Format.fprintf fmt "This is an lvalue of type %a."
        Printer.pp_typ (Cil.typeOfLval lval)

  let print_localizable fmt = function
    | PExp (_, _, e) ->
      Format.fprintf fmt "This is a pure C expression of type %a."
        Printer.pp_typ (Cil.typeOf e)
    | PLval (_, _, lval) as loc -> print_lvalue fmt loc lval
    | PVDecl (_, _, vi) ->
      Format.fprintf fmt "This is the declaration of variable %a.@.@."
        Printer.pp_varinfo vi;
      print_varinfo fmt vi
    | PStmt (kf, _) | PStmtStart (kf, _) ->
      Format.fprintf fmt "This is a statement of function %a." print_kf kf
    | _ -> ()

  let get_marker_info loc =
    let buffer = Jbuffer.create () in
    let fmt = Jbuffer.formatter buffer in
    print_localizable fmt loc;
    Format.pp_print_flush fmt ();
    Jbuffer.contents buffer
end

let () = Request.register ~page
    ~kind:`GET ~name:"kernel.ast.info"
    ~descr:(Md.plain "Get textual information about a marker")
    ~input:(module Marker) ~output:(module Jtext)
    Info.get_marker_info

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
