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

let changed_signal = Request.signal ~package ~name:"changed"
    ~descr:(Md.plain "Emitted when the AST has been changed")

let ast_changed () = Request.emit changed_signal

let ast_update_hook f =
  begin
    Ast.add_hook_on_update f;
    Ast.apply_after_computed (fun _ -> f ());
  end

let () = ast_update_hook ast_changed
let () = Annotations.add_hook_on_change ast_changed

(* -------------------------------------------------------------------------- *)
(* --- File Positions                                                     --- *)
(* -------------------------------------------------------------------------- *)

module Position =
struct
  type t = Filepath.position

  let jtype = Data.declare ~package ~name:"source"
      ~descr:(Md.plain "Source file positions.")
      (Jrecord [
          "dir", Jstring;
          "base", Jstring;
          "file", Jstring;
          "line", Jnumber;
        ])

  let to_json p =
    let path = Filepath.(Normalized.to_pretty_string p.pos_path) in
    let file =
      if Server_parameters.has_relative_filepath ()
      then path
      else (p.Filepath.pos_path :> string)
    in
    `Assoc [
      "dir"  , `String (Filename.dirname path) ;
      "base" , `String (Filename.basename path) ;
      "file" , `String file ;
      "line" , `Int p.Filepath.pos_lnum ;
    ]

  let of_json js =
    let fail () = failure_from_type_error "Invalid source format" js in
    match js with
    | `Assoc assoc ->
      begin
        match List.assoc "file" assoc, List.assoc "line" assoc with
        | `String path, `Int line ->
          Log.source ~file:(Filepath.Normalized.of_string path) ~line
        | _, _ -> fail ()
        | exception Not_found -> fail ()
      end
    | _ -> fail ()

end

(* -------------------------------------------------------------------------- *)
(* --- Functions                                                          --- *)
(* -------------------------------------------------------------------------- *)

let jFunction = Data.declare ~package ~name:"fct"
    ~descr:(Md.plain "Function names")
    (Pkg.Jkey "fct")

module Function =
struct
  type t = kernel_function
  let jtype = jFunction
  let to_json kf =
    `String (Kernel_function.get_name kf)
  let of_json js =
    let fn = Js.to_string js in
    try Globals.Functions.find_by_name fn
    with Not_found -> Data.failure "Undefined function '%s'" fn
end

module Fundec =
struct
  type t = fundec
  let jtype = jFunction
  let to_json fundec =
    `String fundec.svar.vname
  let of_json js =
    let fn = Js.to_string js in
    try Kernel_function.get_definition (Globals.Functions.find_by_name fn)
    with Not_found | Kernel_function.No_Definition ->
      Data.failure "Undefined function definition '%s'" fn
end

(* -------------------------------------------------------------------------- *)
(* ---  Generic Markers                                                   --- *)
(* -------------------------------------------------------------------------- *)

module type TagInfo =
sig
  type t
  val name : string
  val descr : string
  val create : t -> string
  module H : Hashtbl.S with type key = t
end

module type Tag =
sig
  include Data.S
  val index : t -> string
  val find : string -> t
end

module MakeTag(T : TagInfo) :
sig
  include Tag with type t = T.t
  val iter : (t * string -> unit) -> unit
  val hook : (t * string -> unit) -> unit
end =
struct

  type t = T.t

  type index = {
    tags : string T.H.t ;
    items : (string,T.t) Hashtbl.t ;
  }

  let index () = {
    tags = T.H.create 0 ;
    items = Hashtbl.create 0 ;
  }

  let module_name = String.capitalize_ascii T.name

  module TYPE : Datatype.S with type t = index =
    Datatype.Make
      (struct
        type t = index
        include Datatype.Undefined
        let reprs = [index()]
        let name = Printf.sprintf "Server.Kernel_ast.%s.TYPE" module_name
        let mem_project = Datatype.never_any_project
      end)

  module STATE = State_builder.Ref(TYPE)
      (struct
        let name = Printf.sprintf "Server.Kernel_ast.%s.STATE" module_name
        let dependencies = []
        let default = index
      end)

  let iter f =
    T.H.iter (fun key str -> f (key, str)) (STATE.get ()).tags

  let hooks = ref []
  let hook f = hooks := !hooks @ [f]

  let index item =
    let { tags ; items } = STATE.get () in
    try T.H.find tags item
    with Not_found ->
      let tag = T.create item in
      T.H.add tags item tag ;
      Hashtbl.add items tag item ;
      List.iter (fun fn -> fn (item,tag)) !hooks ; tag

  let find tag = Hashtbl.find (STATE.get()).items tag

  let jtype = Data.declare ~package ~name:T.name
      ~descr:(Md.plain T.descr)
      (Pkg.Jkey T.name)

  let to_json item = `String (index item)
  let of_json js =
    try find (Js.to_string js)
    with Not_found ->
      Data.failure "invalid %s (%a)" T.name Json.pp_dump js

end

module Decl = MakeTag
    (struct
      open Printer_tag
      type t = declaration
      let name = "decl"
      let descr = "AST Declarations markers"
      module H = Declaration.Hashtbl
      let kid = ref 0
      let create = function
        | SEnum _ -> Printf.sprintf "#E%d" (incr kid ; !kid)
        | SComp _ -> Printf.sprintf "#C%d" (incr kid ; !kid)
        | SType _ -> Printf.sprintf "#T%d" (incr kid ; !kid)
        | SGlobal vi -> Printf.sprintf "#G%d" vi.vid
        | SFunction kf -> Printf.sprintf "#F%d" @@ Kernel_function.get_id kf
    end)

module Marker = MakeTag
    (struct
      open Printer_tag
      type t = localizable
      let name = "marker"
      let descr = "Localizable AST markers"
      module H = Localizable.Hashtbl
      let kid = ref 0
      let create = function
        | PStmt(_,s) -> Printf.sprintf "#s%d" s.sid
        | PStmtStart(_,s) -> Printf.sprintf "#k%d" s.sid
        | PVDecl(_,_,v) -> Printf.sprintf "#v%d" v.vid
        | PLval _ -> Printf.sprintf "#l%d" (incr kid ; !kid)
        | PExp(_,_,e) -> Printf.sprintf "#e%d" e.eid
        | PTermLval _ -> Printf.sprintf "#t%d" (incr kid ; !kid)
        | PGlobal _ -> Printf.sprintf "#g%d" (incr kid ; !kid)
        | PIP _ -> Printf.sprintf "#p%d" (incr kid ; !kid)
        | PType _ -> Printf.sprintf "#y%d" (incr kid ; !kid)
    end)

module Printer = Printer_tag.Make(struct let tag = Marker.index end)

(* -------------------------------------------------------------------------- *)
(* --- Ast Data                                                           --- *)
(* -------------------------------------------------------------------------- *)

module Lval =
struct
  open Printer_tag

  type t = kinstr * lval
  let jtype = Marker.jtype

  let to_json (kinstr, lval) =
    let kf = match kinstr with
      | Kglobal -> None
      | Kstmt stmt -> Some (Kernel_function.find_englobing_kf stmt)
    in
    Marker.to_json (PLval (kf, kinstr, lval))

  let find = function
    | PLval (_, kinstr, lval) -> kinstr, lval
    | PVDecl (_, kinstr, vi) -> kinstr, Cil.var vi
    | PGlobal (GVar (vi, _, _) | GVarDecl (vi, _)) -> Kglobal, Cil.var vi
    | _ -> raise Not_found

  let mem tag = try let _ = find tag in true with Not_found -> false

  let of_json js =
    try find (Marker.of_json js)
    with Not_found -> Data.failure "not a lval marker"

end

module Stmt =
struct
  type t = stmt
  let jtype = Marker.jtype
  let to_json st =
    let kf = Kernel_function.find_englobing_kf st in
    Marker.to_json (PStmtStart(kf,st))
  let of_json js =
    let open Printer_tag in
    match Marker.of_json js with
    | PStmt(_,st) | PStmtStart(_,st) -> st
    | _ -> Data.failure "not a stmt marker"
end

module Kinstr =
struct
  type t = kinstr
  let jtype = Pkg.Joption Marker.jtype
  let to_json = function
    | Kglobal -> `Null
    | Kstmt st -> Stmt.to_json st
  let of_json = function
    | `Null -> Kglobal
    | js -> Kstmt (Stmt.of_json js)
end

(* -------------------------------------------------------------------------- *)
(* --- Record for (Kf * Marker)                                           --- *)
(* -------------------------------------------------------------------------- *)

module Location =
struct
  type t = Function.t * Marker.t
  let jtype = Data.declare
      ~package ~name:"location"
      ~descr:(Md.plain "Location: function and marker")
      (Jrecord ["fct", Function.jtype; "marker", Marker.jtype])
  let to_json (kf, loc) = `Assoc [
      "fct", Function.to_json kf ;
      "marker", Marker.to_json loc ;
    ]
  let of_json js =
    Json.field "fct" js |> Function.of_json,
    Json.field "marker" js |> Marker.of_json
end

(* -------------------------------------------------------------------------- *)
(* --- Declaration Attributes                                                  --- *)
(* -------------------------------------------------------------------------- *)


module DeclKind =
struct
  open Printer_tag
  type t = declaration
  let jtype = Data.declare
      ~package ~name:"declKind"
      ~descr:(Md.plain "Declaration kind")
      (Junion [
          Jkey "ENUM";
          Jkey "UNION";
          Jkey "STRUCT";
          Jkey "TYPEDEF";
          Jkey "GLOBAL";
          Jkey "FUNCTION";
        ])
  let to_json = function
    | SEnum _ -> `String "ENUM"
    | SComp { cstruct = true } -> `String "STRUCT"
    | SComp { cstruct = false } -> `String "UNION"
    | SType _ -> `String "TYPEDEF"
    | SGlobal _ -> `String "GLOBAL"
    | SFunction _ -> `String "FUNCTION"
end

module DeclAttributes =
struct
  module P = Printer_tag

  let model = States.model ()

  let () =
    States.column
      ~name:"kind"
      ~descr:(Md.plain "Declaration kind")
      ~data:(module DeclKind)
      ~get:fst
      model

  let () =
    States.column
      ~name:"name"
      ~descr:(Md.plain "Declaration identifier")
      ~data:(module Jstring)
      ~get:(fun (decl,_) -> P.name_of_declaration decl)
      model

  let () =
    States.column
      ~name:"label"
      ~descr:(Md.plain "Declaration label (uncapitalized kind & name)")
      ~data:(module Jstring)
      ~get:(fun (decl,_) -> Pretty_utils.to_string P.pp_declaration decl)
      model

  let () =
    States.column
      ~name:"source"
      ~descr:(Md.plain "Source location")
      ~data:(module Position)
      ~get:(fun (decl,_) -> fst @@ P.loc_of_declaration decl)
      model

  let array = States.register_array
      ~package
      ~name:"declAttributes"
      ~descr:(Md.plain "Declaration attributes")
      ~key:snd
      ~keyName:"marker"
      ~keyType:Decl.jtype
      ~iter:Decl.iter
      ~add_reload_hook:ast_update_hook
      model

  let () = Decl.hook (States.update array)

end

(* -------------------------------------------------------------------------- *)
(* --- Marker Attributes                                                  --- *)
(* -------------------------------------------------------------------------- *)

module MarkerAttributes =
struct
  open Printer_tag

  let descr ~short m =
    match varinfo_of_localizable m with
    | Some vi ->
      if Globals.Functions.mem vi then "Function" else
      if vi.vglob then
        if short then "Global" else "Global Variable"
      else if vi.vformal then
        if short then "Formal" else "Formal Parameter"
      else if vi.vtemp then
        if short then "Temp" else "Temporary Variable (generated)"
      else
      if short then "Local" else "Local Variable"
    | None ->
      match m with
      | PStmt _ | PStmtStart _ -> if short then "Stmt" else "Statement"
      | PLval _ -> if short then "Lval" else "L-value"
      | PTermLval _ -> if short then "Lval" else "ACSL L-value"
      | PVDecl _ -> assert false
      | PExp _ -> if short then "Expr" else "Expression"
      | PIP _ -> if short then "Prop" else "Property"
      | PGlobal _ -> if short then "Decl" else "Declaration"
      | PType _ -> "Type"

  let is_function tag =
    match varinfo_of_localizable tag with
    | Some vi -> Globals.Functions.mem vi
    | None -> false

  let is_function_pointer = function
    | PLval (_, _, (Mem _, NoOffset as lval))
      when Cil.(isFunctionType (typeOfLval lval)) -> true
    | PLval (_, _, lval)
      when Cil.(isFunPtrType (Cil.typeOfLval lval)) -> true
    | _ -> false

  let is_fundecl = function
    | PVDecl(Some _,Kglobal,vi) -> vi.vglob && Globals.Functions.mem vi
    | _ -> false

  (*TODO: decprecated, to be changed to declaration tag *)
  let scope tag =
    Option.map Kernel_function.get_name @@ Printer_tag.kf_of_localizable tag

  let model = States.model ()

  let () =
    States.column
      ~name:"labelKind"
      ~descr:(Md.plain "Marker kind (short)")
      ~data:(module Jalpha)
      ~get:(fun (tag,_) -> descr ~short:true tag)
      model

  let () =
    States.column
      ~name:"titleKind"
      ~descr:(Md.plain "Marker kind (long)")
      ~data:(module Jalpha)
      ~get:(fun (tag,_) -> descr ~short:false tag)
      model

  let () =
    States.column
      ~name:"name"
      ~descr:(Md.plain "Marker short name or identifier when relevant.")
      ~data:(module Jalpha)
      ~get:(fun (tag, _) -> Printer_tag.label tag)
      model

  let () =
    States.column
      ~name:"descr"
      ~descr:(Md.plain "Marker description")
      ~data:(module Jstring)
      ~get:(fun (tag, _) -> Rich_text.to_string Printer_tag.pp_localizable tag)
      model

  let () =
    States.column
      ~name:"isLval"
      ~descr:(Md.plain "Whether it is an l-value")
      ~data:(module Jbool)
      ~get:(fun (tag, _) -> Lval.mem tag)
      model

  let () =
    States.column
      ~name:"isFunction"
      ~descr:(Md.plain "Whether it is a function symbol")
      ~data:(module Jbool)
      ~get:(fun (tag, _) -> is_function tag)
      model

  let () =
    States.column
      ~name:"isFunctionPointer"
      ~descr:(Md.plain "Whether it is a function pointer")
      ~data:(module Jbool)
      ~get:(fun (tag, _) -> is_function_pointer tag)
      model

  let () =
    States.column
      ~name:"isFunDecl"
      ~descr:(Md.plain "Whether it is a function declaration")
      ~data:(module Jbool)
      ~get:(fun (tag, _) -> is_fundecl tag)
      model

  let () =
    States.option
      ~name:"scope"
      ~descr:(Md.plain "Function scope of the marker, if applicable")
      ~data:(module Jstring)
      ~get:(fun (tag, _) -> scope tag)
      model

  let () =
    let get (tag, _) =
      let pos = fst (Printer_tag.loc_of_localizable tag) in
      if Cil_datatype.Position.(equal unknown pos) then None else Some pos
    in
    States.option
      ~name:"sloc"
      ~descr:(Md.plain "Source location")
      ~data:(module Position)
      ~get
      model

  let array = States.register_array
      ~package
      ~name:"markerAttributes"
      ~descr:(Md.plain "Marker attributes")
      ~key:snd
      ~keyName:"marker"
      ~keyType:Marker.jtype
      ~iter:Marker.iter
      ~add_reload_hook:ast_update_hook
      model

  let () = Marker.hook (States.update array)

end

(* -------------------------------------------------------------------------- *)
(* --- Functions                                                          --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register ~package
    ~kind:`GET ~name:"getMainFunction"
    ~descr:(Md.plain "Get the current 'main' function.")
    ~input:(module Junit) ~output:(module Joption(Function))
    begin fun () ->
      try Some (fst (Globals.entry_point ()))
      with Globals.No_such_entry_point _ -> None
    end

let () = Request.register ~package
    ~kind:`GET ~name:"getFunctions"
    ~descr:(Md.plain "Collect all functions in the AST")
    ~input:(module Junit) ~output:(module Jlist(Function))
    begin fun () ->
      let pool = ref [] in
      Globals.Functions.iter (fun kf -> pool := kf :: !pool) ;
      List.rev !pool
    end

let () = Request.register ~package
    ~kind:`GET ~name:"printFunction"
    ~descr:(Md.plain "Print the AST of a function")
    ~signals:[changed_signal]
    ~input:(module Function) ~output:(module Jtext)
    begin fun kf ->
      let libc = Kernel.PrintLibc.get () in
      try
        if not libc then Kernel.PrintLibc.set true ;
        let global = Kernel_function.get_global kf in
        let pp_glb = Printer.(with_unfold_precond (fun _ -> true) pp_global) in
        let ast = Jbuffer.to_json pp_glb global in
        if not libc then Kernel.PrintLibc.set false ; ast
      with err ->
        if not libc then Kernel.PrintLibc.set false ; raise err
    end

module Functions =
struct

  let key kf = Printf.sprintf "kf#%d" (Kernel_function.get_id kf)

  let signature kf =
    let g = Kernel_function.get_global kf in
    let libc = Kernel.PrintLibc.get () in
    try
      if not libc then Kernel.PrintLibc.set true ;
      let txt = Rich_text.to_string Printer_tag.pp_localizable (PGlobal g) in
      if not libc then Kernel.PrintLibc.set false ;
      if Kernel_function.is_entry_point kf then (txt ^ " /* main */") else txt
    with err ->
      if not libc then Kernel.PrintLibc.set false ; raise err

  let is_builtin kf =
    Cil_builtins.is_builtin (Kernel_function.get_vi kf)

  let is_extern kf =
    let vi = Kernel_function.get_vi kf in
    vi.vstorage = Extern

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
        ~get:Kernel_function.is_in_libc;
      States.column model
        ~name:"builtin"
        ~descr:(Md.plain "Is the function a Frama-C builtin?")
        ~data:(module Data.Jbool)
        ~default:false
        ~get:is_builtin;
      States.column model
        ~name:"extern"
        ~descr:(Md.plain "Is the function extern?")
        ~data:(module Data.Jbool)
        ~default:false
        ~get:is_extern;
      States.column model
        ~name:"sloc"
        ~descr:(Md.plain "Source location")
        ~data:(module Position)
        ~get:(fun kf -> fst (Kernel_function.get_location kf));
      States.register_array model
        ~package ~key
        ~name:"functions"
        ~descr:(Md.plain "AST Functions")
        ~iter
        ~add_reload_hook:ast_update_hook
    end

end

(* -------------------------------------------------------------------------- *)
(* --- Marker Information                                                 --- *)
(* -------------------------------------------------------------------------- *)

module Information =
struct

  type info = {
    id: string;
    rank: int;
    label: string; (* short name *)
    title: string; (* full title name *)
    descr: string; (* description for information values *)
    enable: unit -> bool;
    pretty: Format.formatter -> Printer_tag.localizable -> unit
  }

  (* Info markers serialization *)

  module S =
  struct
    type t = (info * Jtext.t)
    let jtype = Package.(Jrecord[
        "id", Jstring ;
        "label", Jstring ;
        "title", Jstring ;
        "descr", Jstring ;
        "text", Jtext.jtype ;
      ])
    let of_json _ = failwith "Information.Info"
    let to_json (info,text) = `Assoc [
        "id", `String info.id ;
        "label", `String info.label ;
        "title", `String info.title ;
        "descr", `String info.descr ;
        "text", text ;
      ]
  end

  (* Info markers registry *)

  let rankId = ref 0
  let registry : (string,info) Hashtbl.t = Hashtbl.create 0

  let jtext pp marker =
    try
      let buffer = Jbuffer.create () in
      let fmt = Jbuffer.formatter buffer in
      pp fmt marker;
      Format.pp_print_flush fmt ();
      Jbuffer.contents buffer
    with Not_found ->
      `Null

  let rank ({rank},_) = rank
  let by_rank a b = Stdlib.compare (rank a) (rank b)

  let get_information tgt =
    let infos = ref [] in
    Hashtbl.iter
      (fun _ info ->
         if info.enable () then
           match tgt with
           | None -> infos := (info, `Null) :: !infos
           | Some marker ->
             let text = jtext info.pretty marker in
             if not (Jbuffer.is_empty text) then
               infos := (info, text) :: !infos
      ) registry ;
    List.sort by_rank !infos

  let signal = Request.signal ~package
      ~name:"getInformationUpdate"
      ~descr:(Md.plain "Updated AST information")

  let update () = Request.emit signal

  let register ~id ~label ~title
      ?(descr = title)
      ?(enable = fun _ -> true)
      pretty =
    let rank = incr rankId ; !rankId in
    let info = { id ; rank ; label ; title ; descr; enable ; pretty } in
    if Hashtbl.mem registry id then
      ( let msg = Format.sprintf
            "Server.Kernel_ast.register_info: duplicate %S" id in
        raise (Invalid_argument msg) );
    Hashtbl.add registry id info

end

let () = Request.register ~package
    ~kind:`GET ~name:"getInformation"
    ~descr:(Md.plain
              "Get available information about markers. \
               When no marker is given, returns all kinds \
               of information (with empty `descr` field).")
    ~input:(module Joption(Marker))
    ~output:(module Jlist(Information.S))
    ~signals:[Information.signal]
    Information.get_information

(* -------------------------------------------------------------------------- *)
(* --- Default Kernel Information                                         --- *)
(* -------------------------------------------------------------------------- *)

let () = Information.register
    ~id:"kernel.ast.location"
    ~label:"Location"
    ~title:"Source file location"
    begin fun fmt loc ->
      let pos = fst @@ Printer_tag.loc_of_localizable loc in
      if Filepath.Normalized.is_empty pos.pos_path then
        raise Not_found ;
      Filepath.pp_pos fmt pos
    end

let () = Information.register
    ~id:"kernel.ast.varinfo"
    ~label:"Var"
    ~title:"Variable Information"
    begin fun fmt loc ->
      match loc with
      | PLval (_ , _, (Var x,NoOffset)) | PVDecl(_,_,x) ->
        if not x.vreferenced then Format.pp_print_string fmt "unused " ;
        begin
          match x.vstorage with
          | NoStorage -> ()
          | Extern -> Format.pp_print_string fmt "extern "
          | Static -> Format.pp_print_string fmt "static "
          | Register -> Format.pp_print_string fmt "register "
        end ;
        if x.vghost then Format.pp_print_string fmt "ghost " ;
        if x.vaddrof then Format.pp_print_string fmt "aliased " ;
        if x.vformal then Format.pp_print_string fmt "formal" else
        if x.vglob then Format.pp_print_string fmt "global" else
        if x.vtemp then Format.pp_print_string fmt "temporary" else
          Format.pp_print_string fmt "local" ;
      | _ -> raise Not_found
    end

let () = Information.register
    ~id:"kernel.ast.typeinfo"
    ~label:"Type"
    ~title:"Type of C/ASCL expression"
    begin fun fmt loc ->
      let open Printer in
      match loc with
      | PExp (_, _, e) -> pp_typ fmt (Cil.typeOf e)
      | PLval (_, _, lval) -> pp_typ fmt (Cil.typeOfLval lval)
      | PTermLval(_,_,_,lv) -> pp_logic_type fmt (Cil.typeOfTermLval lv)
      | PVDecl (_,_,vi) -> pp_typ fmt vi.vtype
      | _ -> raise Not_found
    end

let () = Information.register
    ~id:"kernel.ast.typedef"
    ~label:"Typedef"
    ~title:"Type Definition"
    begin fun fmt loc ->
      match loc with
      | PGlobal
          (( GType _
           | GCompTag _ | GCompTagDecl _
           | GEnumTag _ | GEnumTagDecl _
           ) as g) -> Printer.pp_global fmt g
      | _ -> raise Not_found
    end

let () = Information.register
    ~id:"kernel.ast.typesizeof"
    ~label:"Sizeof"
    ~title:"Size of a C-type or C-variable"
    begin fun fmt loc ->
      let typ =
        match loc with
        | PType typ -> typ
        | PVDecl(_,_,vi) -> vi.vtype
        | PGlobal (GType(ti,_)) -> ti.ttype
        | PGlobal (GCompTagDecl(ci,_) | GCompTag(ci,_)) -> TComp(ci,[])
        | PGlobal (GEnumTagDecl(ei,_) | GEnumTag(ei,_)) -> TEnum(ei,[])
        | _ -> raise Not_found
      in
      let bits =
        try Cil.bitsSizeOf typ
        with Cil.SizeOfError _ -> raise Not_found
      in
      let bytes = bits / 8 in
      let rbits = bits mod 8 in
      if rbits > 0 then
        if bytes > 0 then
          Format.fprintf fmt "%d bytes + %d bits" bytes rbits
        else
          Format.fprintf fmt "%d bits" rbits
      else
        Format.fprintf fmt "%d bytes" bytes
    end

let () = Information.register
    ~id:"kernel.ast.marker"
    ~label:"Marker"
    ~title:"Ivette marker (for debugging)"
    ~enable:(fun _ -> Server_parameters.debug_atleast 1)
    begin fun fmt loc ->
      let tag = Marker.index loc in
      Format.fprintf fmt "%S" tag
    end

let () = Server_parameters.Debug.add_hook_on_update
    (fun _ -> Information.update ())

(* -------------------------------------------------------------------------- *)
(* --- Marker at a position                                               --- *)
(* -------------------------------------------------------------------------- *)

let get_kf_marker (file, line, col) =
  let pos_path = Filepath.Normalized.of_string file in
  let pos =
    Filepath.{ pos_path; pos_lnum = line; pos_cnum = col; pos_bol = 0; }
  in
  let tag = Printer_tag.loc_to_localizable ~precise_col:true pos in
  let kf = Option.bind tag Printer_tag.kf_of_localizable in
  kf, tag

let () =
  let descr =
    Md.plain
      "Returns the marker and function at a source file position, if any. \
       Input: file path, line and column."
  in
  Request.register
    ~package ~descr ~kind:`GET ~name:"getMarkerAt"
    ~input:(module Jtriple (Jstring) (Jint) (Jint))
    ~output:(module Jpair (Joption (Function)) (Joption (Marker)))
    get_kf_marker

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
(* --- Build a marker from an ACSL term                                   --- *)
(* -------------------------------------------------------------------------- *)

let build_marker ~stmt ~term =
  let env =
    let open Logic_typing in
    Lenv.empty () |> append_pre_label |> append_init_label |> append_here_label
  in
  try
    let kf = Kernel_function.find_englobing_kf stmt in
    let term = Logic_parse_string.term ~env kf term in
    let exp = Logic_to_c.term_to_exp term in
    Some (Printer_tag.PExp (Some kf, Kstmt stmt, exp))
  with Not_found
     | Logic_parse_string.Error _
     | Logic_parse_string.Unbound _
     | Logic_to_c.No_conversion -> None (* TODO: return an error message. *)

let () =
  let module Md = Markdown in
  let s = Request.signature ~output:(module Marker) () in
  let get_marker = Request.param s ~name:"stmt"
      ~descr:(Md.plain "Marker position from where to localize the term")
      (module Marker) in
  let get_term = Request.param s ~name:"term"
      ~descr:(Md.plain "ACSL term to parse")
      (module Data.Jstring) in
  Request.register_sig ~package s
    ~kind:`GET ~name:"parseExpr"
    ~descr:(Md.plain "Parse a C expression and returns the associated marker")
    begin fun rq () ->
      match Printer_tag.ki_of_localizable @@ get_marker rq with
      | Kglobal -> Data.failure "No statement at selection point"
      | Kstmt stmt ->
        match build_marker ~stmt ~term:(get_term rq) with
        | None -> Data.failure "Invalid expression"
        | Some tag -> tag
    end

(* -------------------------------------------------------------------------- *)
