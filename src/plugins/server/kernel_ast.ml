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
module Md = Markdown
module Js = Yojson.Basic.Util
module Pkg = Package
open Cil_types

let package = Pkg.package ~title:"Ast Services" ~name:"ast" ~readme:"ast.md" ()

(* -------------------------------------------------------------------------- *)
(* --- Compute Ast                                                        --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register ~package
    ~kind:`EXEC ~name:"compute"
    ~descr:(Md.plain "Ensures that AST is computed")
    ~input:(module Junit) ~output:(module Junit) Ast.compute

(* -------------------------------------------------------------------------- *)
(* ---  Printers                                                          --- *)
(* -------------------------------------------------------------------------- *)

(* The kind of a marker. *)
module MarkerKind = struct

  let kinds = Enum.dictionary ()

  let kind name =
    Enum.tag
      ~name
      ~descr:(Md.plain (String.capitalize_ascii name))
      kinds

  let expr = kind "expression"
  let lval = kind "lvalue"
  let decl = kind "declaration"
  let stmt = kind "statement"
  let glob = kind "global"
  let term = kind "term"
  let prop = kind "property"

  let () =
    Enum.set_lookup
      kinds
      (fun localizable ->
         let open Printer_tag in
         match localizable with
         | PStmt _ -> stmt
         | PStmtStart _ -> stmt
         | PVDecl _ -> decl
         | PLval _ -> lval
         | PExp _ -> expr
         | PTermLval _ -> term
         | PGlobal _ -> glob
         | PIP _ -> prop)

  let data =
    Request.dictionary
      ~package
      ~name:"markerKind"
      ~descr:(Md.plain "Marker kind")
      kinds

  include (val data : S with type t = Printer_tag.localizable)
end

module MarkerVar = struct

  let vars = Enum.dictionary ()

  let kind name =
    Enum.tag
      ~name
      ~descr:(Md.plain (String.capitalize_ascii name))
      vars

  let none = kind "none"
  let var = kind "variable"
  let fct = kind "function"

  let () =
    Enum.set_lookup
      vars
      (fun localizable ->
         let open Printer_tag in
         match localizable with
         | PLval (_, _, (Var vi, NoOffset))
         | PVDecl (_, _, vi)
         | PGlobal (GVar (vi, _, _)  | GVarDecl (vi, _)) ->
           if Cil.isFunctionType vi.vtype then fct else var
         | PGlobal (GFun _ | GFunDecl _) -> fct
         | PLval _ | PStmt _ | PStmtStart _
         | PExp _ | PTermLval _ | PGlobal _ | PIP _ -> none)

  let data =
    Request.dictionary
      ~package
      ~name:"markerVar"
      ~descr:(Md.plain "Marker variable")
      vars

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
      States.column
        ~name:"kind"
        ~descr:(Md.plain "Marker kind")
        ~data:(module MarkerKind)
        ~get:fst
        model
    in
    let () =
      States.column
        ~name:"var"
        ~descr:(Md.plain "Marker variable")
        ~data:(module MarkerVar)
        ~get:fst
        model
    in
    let () =
      States.column
        ~name:"name"
        ~descr:(Md.plain "Marker short name")
        ~data:(module Jalpha)
        ~get:(fun (tag, _) -> Printer_tag.label tag)
        model
    in
    let () =
      States.column
        ~name:"descr"
        ~descr:(Md.plain "Marker declaration or description")
        ~data:(module Jstring)
        ~get:(fun (tag, _) -> Rich_text.to_string Printer_tag.pretty tag)
        model
    in
    let () =
      States.column
        ~name:"sloc"
        ~descr:(Md.plain "Source location")
        ~data:(module Kernel_main.LogSource)
        ~get:(fun (tag, _) -> fst (Printer_tag.loc_of_localizable tag))
        model
    in
    States.register_array
      ~package
      ~name:"markerInfo"
      ~descr:(Md.plain "Marker informations")
      ~key:snd ~keyType:Jstring
      ~iter model

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

  let markers = ref []
  let jmarker kd =
    let jt = Pkg.Jkey kd in markers := jt :: !markers ; jt

  let jstmt = jmarker "stmt"
  let jdecl = jmarker "decl"
  let jlval = jmarker "lval"
  let jexpr = jmarker "expr"
  let jterm = jmarker "term"
  let jglobal = jmarker "global"
  let jproperty = jmarker "property"

  let jtype = Data.declare ~package ~name:"marker"
      ~descr:(Md.plain "Localizable AST markers")
      Pkg.(Junion (List.rev !markers))

  let to_json loc = `String (create loc)
  let of_json js =
    try lookup (Js.to_string js)
    with Not_found -> Data.failure "not a localizable marker"

end

module Printer = Printer_tag.Make(Marker)

(* -------------------------------------------------------------------------- *)
(* --- Ast Data                                                           --- *)
(* -------------------------------------------------------------------------- *)

module Lval =
struct
  type t = kinstr * lval
  let jtype = Marker.jlval
  let to_json (kinstr, lval) =
    let kf = match kinstr with
      | Kglobal -> None
      | Kstmt stmt -> Some (Kernel_function.find_englobing_kf stmt)
    in
    Marker.to_json (PLval (kf, kinstr, lval))
  let of_json js =
    let open Printer_tag in
    match Marker.of_json js with
    | PLval (_, kinstr, lval) -> kinstr, lval
    | PVDecl (_, kinstr, vi) -> kinstr, Cil.var vi
    | PGlobal (GVar (vi, _, _) | GVarDecl (vi, _)) -> Kglobal, Cil.var vi
    | _ -> Data.failure "not a lval marker"
end

module Stmt =
struct
  type t = stmt
  let jtype = Marker.jstmt
  let to_json st =
    let kf = Kernel_function.find_englobing_kf st in
    Marker.to_json (PStmt(kf,st))
  let of_json js =
    let open Printer_tag in
    match Marker.of_json js with
    | PStmt(_,st) | PStmtStart(_,st) -> st
    | _ -> Data.failure "not a stmt marker"
end

module Ki =
struct
  type t = kinstr
  let jtype = Pkg.Joption Marker.jstmt
  let to_json = function
    | Kglobal -> `Null
    | Kstmt st -> Stmt.to_json st
  let of_json = function
    | `Null -> Kglobal
    | js -> Kstmt (Stmt.of_json js)
end

module Kf =
struct
  type t = kernel_function
  let jtype = Pkg.Jkey "fct"
  let to_json kf =
    `String (Kernel_function.get_name kf)
  let of_json js =
    let key = Js.to_string js in
    try Globals.Functions.find_by_name key
    with Not_found -> Data.failure "Undefined function '%s'" key
end

module KfMarker = struct
  type record
  let record : record Record.signature = Record.signature ()
  let fct = Record.field record ~name:"fct"
      ~descr:(Md.plain "Function") (module Kf)
  let marker = Record.field record ~name:"marker"
      ~descr:(Md.plain "Marker") (module Marker)

  let data =
    Record.publish ~package ~name:"location"
      ~descr:(Md.plain "Location: function and marker") record
  module R : Record.S with type r = record = (val data)
  type t = kernel_function * Printer_tag.localizable
  let jtype = R.jtype

  let to_json (kf, loc) =
    R.default |>
    R.set fct kf |>
    R.set marker loc |>
    R.to_json

  let of_json json =
    let r = R.of_json json in
    R.get fct r, R.get marker r
end

(* -------------------------------------------------------------------------- *)
(* --- Functions                                                          --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register ~package
    ~kind:`GET ~name:"getFunctions"
    ~descr:(Md.plain "Collect all functions in the AST")
    ~input:(module Junit) ~output:(module Jlist(Kf))
    begin fun () ->
      let pool = ref [] in
      Globals.Functions.iter (fun kf -> pool := kf :: !pool) ;
      List.rev !pool
    end

let () = Request.register ~package
    ~kind:`GET ~name:"printFunction"
    ~descr:(Md.plain "Print the AST of a function")
    ~input:(module Kf) ~output:(module Jtext)
    begin fun kf ->
      let libc = Kernel.PrintLibc.get () in
      try
        if not libc then Kernel.PrintLibc.set true ;
        let global = Kernel_function.get_global kf in
        let ast = Jbuffer.to_json Printer.pp_global global in
        if not libc then Kernel.PrintLibc.set false ; ast
      with err ->
        if not libc then Kernel.PrintLibc.set false ; raise err
    end

module Functions =
struct

  let key kf = Printf.sprintf "kf#%d" (Kernel_function.get_id kf)

  let signature kf =
    let global = Kernel_function.get_global kf in
    let libc = Kernel.PrintLibc.get () in
    try
      if not libc then Kernel.PrintLibc.set true ;
      let txt = Rich_text.to_string Printer_tag.pretty (PGlobal global) in
      if not libc then Kernel.PrintLibc.set false ;
      if Kernel_function.is_entry_point kf then (txt ^ " /* main */") else txt
    with err ->
      if not libc then Kernel.PrintLibc.set false ; raise err

  let is_builtin kf =
    Cil_builtins.is_builtin (Kernel_function.get_vi kf)

  let is_stdlib kf =
    let vi = Kernel_function.get_vi kf in
    Cil.is_in_libc vi.vattr

  let is_eva_analyzed kf =
    if Db.Value.is_computed () then !Db.Value.is_called kf else false

  let iter f =
    Globals.Functions.iter
      (fun kf ->
         let name = Kernel_function.get_name kf in
         if not (Ast_info.is_frama_c_builtin name) then f kf)

  let array : kernel_function States.array =
    begin
      let model = States.model () in
      States.column model
        ~name:"name"
        ~descr:(Md.plain "Name")
        ~data:(module Data.Jalpha)
        ~get:Kernel_function.get_name ;
      States.column model
        ~name:"signature"
        ~descr:(Md.plain "Signature")
        ~data:(module Data.Jstring)
        ~get:signature ;
      States.column model
        ~name:"main"
        ~descr:(Md.plain "Is the function the main entry point")
        ~data:(module Data.Jbool)
        ~default:false
        ~get:Kernel_function.is_entry_point;
      States.column model
        ~name:"defined"
        ~descr:(Md.plain "Is the function defined?")
        ~data:(module Data.Jbool)
        ~default:false
        ~get:Kernel_function.is_definition;
      States.column model
        ~name:"stdlib"
        ~descr:(Md.plain "Is the function from the Frama-C stdlib?")
        ~data:(module Data.Jbool)
        ~default:false
        ~get:is_stdlib;
      States.column model
        ~name:"builtin"
        ~descr:(Md.plain "Is the function a Frama-C builtin?")
        ~data:(module Data.Jbool)
        ~default:false
        ~get:is_builtin;
      States.column model
        ~name:"eva_analyzed"
        ~descr:(Md.plain "Has the function been analyzed by Eva")
        ~data:(module Data.Jbool)
        ~default:false
        ~get:is_eva_analyzed;
      States.column model
        ~name:"sloc"
        ~descr:(Md.plain "Source location")
        ~data:(module Kernel_main.LogSource)
        ~get:(fun kf -> fst (Kernel_function.get_location kf));
      States.register_array model
        ~package ~key
        ~name:"functions"
        ~descr:(Md.plain "AST Functions")
        ~iter
        ~add_reload_hook:Ast.add_hook_on_update ;
    end

end

(* -------------------------------------------------------------------------- *)
(* --- Information                                                        --- *)
(* -------------------------------------------------------------------------- *)

module Info = struct
  open Printer_tag

  let print_function fmt name =
    let stag = Format.String_tag name in
    Format.pp_open_stag fmt stag;
    Format.pp_print_string fmt name;
    Format.pp_close_stag fmt ()

  let print_kf fmt kf = print_function fmt (Kernel_function.get_name kf)

  let print_variable fmt vi =
    Format.fprintf fmt "Variable %s has type %a.@."
      vi.vname Printer.pp_typ vi.vtype;
    let kf = Kernel_function.find_defining_kf vi in
    let pp_kf fmt kf = Format.fprintf fmt " of function %a" print_kf kf in
    Format.fprintf fmt "It is a %s variable%a.@."
      (if vi.vglob then "global" else if vi.vformal then "formal" else "local")
      (Format.pp_print_option pp_kf) kf;
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

let () = Request.register ~package
    ~kind:`GET ~name:"getInfo"
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
    ~package
    ~descr:(Md.plain "Get the currently analyzed source file names")
    ~kind:`GET
    ~name:"getFiles"
    ~input:(module Junit) ~output:(module Jlist(Jstring))
    get_files

let set_files files =
  let s = String.concat "," files in
  Kernel.Files.As_string.set s

let () =
  Request.register
    ~package
    ~descr:(Md.plain "Set the source file names to analyze.")
    ~kind:`SET
    ~name:"setFiles"
    ~input:(module Jlist(Jstring))
    ~output:(module Junit)
    set_files

(* -------------------------------------------------------------------------- *)
