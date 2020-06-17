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

(* -------------------------------------------------------------------------- *)

module Senv = Server_parameters
module Md = Markdown

(* -------------------------------------------------------------------------- *)

type plugin = Kernel | Plugin of string
type path = string list
type ident = { plugin: plugin; package: path; name: string }

let pp_plugin fmt = function
  | Kernel -> Format.pp_print_string fmt "Kernel"
  | Plugin p -> Format.fprintf fmt "Plugin %s" p

let pp_step fmt a =
  ( Format.pp_print_string fmt a ; Format.pp_print_char fmt '.' )

let pp_plugin_step fmt = function
  | Kernel -> ()
  | Plugin p -> pp_step fmt p

let pp_ident fmt { plugin ; package ; name } =
  ( pp_plugin_step fmt plugin ;
    List.iter (pp_step fmt) package ;
    Format.pp_print_string fmt name )

(* -------------------------------------------------------------------------- *)
(* --- Name Resolution                                                    --- *)
(* -------------------------------------------------------------------------- *)

module Std = Transitioning.Stdlib
module Id = struct type t = ident let compare = Std.compare end
module IdMap = Map.Make(Id)
module IdSet = Set.Make(Id)
module NameSet = Set.Make(String)

module Scope =
struct

  let rec inpkg ids = function
    | [] -> ids
    | [p] -> p::ids
    | _::ps -> inpkg ids ps

  let relative ~source ~target ids =
    if target = source then ids else
      match target with
      | Kernel -> ids
      | Plugin p -> p::ids

  let target p ids =
    match p with
    | Kernel -> "kernel" :: ids
    | Plugin p -> "plugin" :: p :: ids

  (* propose various abbreviations ; finally render full qualified name *)
  let ranked source { plugin ; package ; name } k =
    String.concat "_" @@
    let name = [name] in
    match k with
    | 0 -> name
    | 1 -> relative ~source ~target:plugin name
    | 2 -> relative ~source ~target:plugin (inpkg name package)
    | 3 -> relative ~source ~target:plugin (package @ name)
    | _ -> target plugin (package @ name)

  type t = {
    source : plugin ;
    mutable clashes : bool ;
    mutable index : (string,int IdMap.t) Hashtbl.t ;
    mutable names : string IdMap.t ;
    mutable reserved : NameSet.t ;
  }

  let create source = {
    source ;
    index = Hashtbl.create 0 ;
    clashes = false ;
    names = IdMap.empty ;
    reserved = NameSet.empty ;
  }

  let rec non_reserved scope id rk =
    let a = ranked scope.source id rk in
    if NameSet.mem a scope.reserved then
      non_reserved scope id (succ rk)
    else a,rk

  let push scope id rk =
    begin
      let name, rk = non_reserved scope id rk in
      scope.names <- IdMap.add id name scope.names ;
      let index = scope.index in
      match Hashtbl.find_opt index name with
      | None ->
        Hashtbl.add index name (IdMap.add id rk IdMap.empty)
      | Some idks ->
        if IdMap.mem id idks then
          scope.clashes <- true
        else
          Hashtbl.replace index name (IdMap.add id rk idks)
    end

  let use scope id =
    if not (IdMap.mem id scope.names) then
      push scope id 0

  let reserve scope name =
    assert (IdMap.is_empty scope.names) ;
    scope.reserved <- NameSet.add name scope.reserved

  let declare scope id =
    begin
      let { name } = id in
      if NameSet.mem name scope.reserved then
        Senv.fatal "Reserved name for identifier '%a'" pp_ident id ;
      scope.names <- IdMap.add id name scope.names ;
      scope.reserved <- NameSet.add name scope.reserved ;
    end

  let rec resolve scope =
    if not scope.clashes then scope.names else
      begin
        let index = scope.index in
        scope.index <- Hashtbl.create 0 ;
        scope.clashes <- false ;
        Hashtbl.iter
          (fun name idks ->
             match IdMap.bindings idks with
             | [id,rk] ->
               push scope id rk
             | idks ->
               Format.eprintf "CLASHING %S@." name ;
               List.iter (fun (id,rk) ->
                   Format.eprintf "RANK %a %d@." pp_ident id rk ;
                   push scope id (succ rk)
                 ) idks
          ) index ;
        resolve scope
      end

end

(* -------------------------------------------------------------------------- *)
(* --- JSON Datatypes                                                     --- *)
(* -------------------------------------------------------------------------- *)

type jtype =
  | Jany
  | Jnull
  | Jboolean
  | Jnumber
  | Jstring
  | Jtag of string
  | Jkey of string (* kind of a string used for indexing *)
  | Jindex of string (* kind of a number used for indexing *)
  | Joption of jtype
  | Jassoc of string * jtype (* kind of keys *)
  | Jarray of jtype
  | Jtuple of jtype list
  | Junion of jtype list
  | Jrecord of (string * jtype) list
  | Jdata of ident
  | Jself (* for (simply) recursive types *)

(* -------------------------------------------------------------------------- *)
(* --- Declarations                                                       --- *)
(* -------------------------------------------------------------------------- *)

type fieldInfo = {
  fd_name: string;
  fd_type: jtype;
  fd_descr: Markdown.text;
}

type tagInfo = {
  tg_name: string;
  tg_label: Markdown.text;
  tg_descr: Markdown.text;
}

type paramInfo =
  | P_value of jtype
  | P_named of fieldInfo list

type requestInfo = {
  rq_kind: [ `GET | `SET | `EXEC ];
  rq_input: paramInfo ;
  rq_output: paramInfo ;
}

type declKindInfo =
  | D_signal
  | D_value
  | D_state
  | D_array
  | D_type of jtype
  | D_enum of tagInfo list
  | D_record of fieldInfo list
  | D_request of requestInfo

type declInfo = {
  d_ident : ident;
  d_descr : Markdown.text;
  d_kind : declKindInfo;
}

type packageInfo = {
  d_plugin : plugin ;
  d_package : string list ;
  d_userdoc : Markdown.elements ;
  d_content : declInfo list;
}

let name_of_ident id =
  String.concat "." @@ match id.plugin with
  | Kernel -> "kernel" :: id.package @ [ id.name ]
  | Plugin p -> p :: (id.package @ [id.name ])

let name_of_pkginfo pkg =
  String.concat "." @@ match pkg.d_plugin with
  | Kernel -> "kernel" :: pkg.d_package
  | Plugin p -> p :: pkg.d_package

(* -------------------------------------------------------------------------- *)
(* --- Visitors                                                           --- *)
(* -------------------------------------------------------------------------- *)

let rec visit_jtype fn = function
  | Jany | Jself | Jnull | Jboolean | Jnumber
  | Jstring | Jindex _ | Jkey _ | Jtag _ -> ()
  | Joption js | Jassoc(_,js)  | Jarray js -> visit_jtype fn js
  | Jtuple js | Junion js -> List.iter (visit_jtype fn) js
  | Jrecord fjs -> List.iter (fun (_,js) -> visit_jtype fn js) fjs
  | Jdata id -> fn id

let visit_field f { fd_type } = visit_jtype f fd_type

let visit_param f = function
  | P_value js -> visit_jtype f js
  | P_named fds -> List.iter (visit_field f) fds

let visit_request f { rq_input ; rq_output } =
  ( visit_param f rq_input ; visit_param f rq_output )

let visit_dkind f = function
  | D_signal | D_state | D_value | D_array | D_enum _ -> ()
  | D_type js -> visit_jtype f js
  | D_record fds -> List.iter (visit_field f) fds
  | D_request rq -> visit_request f rq

let visit_decl f { d_kind } = visit_dkind f d_kind

let visit_package_decl f { d_content } =
  List.iter (fun { d_ident } -> f d_ident) d_content

let visit_package_used f { d_content } =
  List.iter (visit_decl f) d_content

let resolve ?(keywords=[]) pkg =
  let scope = Scope.create pkg.d_plugin in
  List.iter (Scope.reserve scope) keywords ;
  visit_package_decl (Scope.declare scope) pkg ;
  visit_package_used (Scope.use scope) pkg ;
  Scope.resolve scope

(* -------------------------------------------------------------------------- *)
(* --- Server API                                                         --- *)
(* -------------------------------------------------------------------------- *)

type package = {
  pkgInfo : packageInfo ; (* with empty decl *)
  mutable revDecl : declInfo list ; (* in reverse order *)
}

let name_of_package pkg = name_of_pkginfo pkg.pkgInfo

let registry = ref IdSet.empty (* including packages *)
let packages = ref [] (* in reverse order *)
let collection = ref None (* computed *)

let name_re = Str.regexp "^[a-zA-Z0-9]+$"
let package_re = Str.regexp "^[a-z0-9]+\\(\\.[a-z0-9]+\\)*$"

let check_name name =
  if not (Str.string_match name_re name 0) then
    Senv.fatal
      "Invalid identifier %S (use « camlCased » names)" name

let check_package pkg =
  if not (Str.string_match package_re pkg 0) then
    Senv.fatal
      "Invalid package identifier %S (use dot separated lowercase names)"
      pkg

let register_ident id =
  if IdSet.mem id !registry then
    Senv.fatal "Duplicate identifier '%a'" pp_ident id ;
  registry := IdSet.add id !registry

let userdoc ~plugin ~title ~descr = function
  | None -> Md.section ~title (Md.par descr)
  | Some readme ->
    let file =
      match plugin with
      | Kernel ->
        Printf.sprintf "%s/server/kernel/%s" Fc_config.datadir readme
      | Plugin name ->
        Printf.sprintf "%s/%s/server/%s" Fc_config.datadir name readme
    in
    if Sys.file_exists file
    then Markdown.rawfile file
    else Markdown.(section ~title (Md.par descr))

(* -------------------------------------------------------------------------- *)
(* --- Declarations                                                       --- *)
(* -------------------------------------------------------------------------- *)

let package ?plugin ~title ?(descr=[]) ?readme ~name () =
  check_package name ;
  let plugin = match plugin with None -> Kernel | Some p -> Plugin p in
  let pkgname = String.split_on_char '.' name in
  let pkgid = { plugin ; package = pkgname ; name = "*"} in
  let userdoc = userdoc ~plugin ~title ~descr readme in
  let pkgInfo = {
    d_plugin = plugin ;
    d_package = pkgname ;
    d_userdoc = userdoc ;
    d_content = [] ;
  } in
  let package = { pkgInfo ; revDecl=[] } in
  register_ident pkgid ;
  collection := None ;
  packages := package :: !packages ;
  package

let declare_id ~package:pkg ~name ?(descr=[]) decl =
  check_name name ;
  let { d_plugin = plugin ; d_package = package } = pkg.pkgInfo in
  let ident = { plugin ; package ; name } in
  let decl = { d_ident=ident ; d_descr=descr ; d_kind=decl } in
  register_ident ident ;
  pkg.revDecl <- decl :: pkg.revDecl ; ident

let declare ~package ~name ?descr decl =
  let _id = declare_id ~package ~name ?descr decl in ()

let update ~package:pkg ~name decl =
  pkg.revDecl <- List.map
      (fun curr ->
         if curr.d_ident.name = name then
           { curr with d_kind = decl }
         else curr
      ) pkg.revDecl

let datatype ~package ~name ?descr jtype =
  Jdata (declare_id ~package ~name ?descr (D_type jtype))

let iter f =
  List.iter f @@
  match !collection with
  | Some pkgs -> pkgs
  | None ->
    let pkgs =
      List.sort (fun a b -> Std.compare a.d_plugin b.d_plugin) @@
      List.rev_map
        (fun pkg -> { pkg.pkgInfo with d_content = List.rev pkg.revDecl })
        !packages
    in collection := Some pkgs ; pkgs

(* -------------------------------------------------------------------------- *)
(* --- JSON To MarkDown                                                   --- *)
(* -------------------------------------------------------------------------- *)

let key kd = Md.plain (Printf.sprintf "`#%s`" kd)
let index kd = Md.plain (Printf.sprintf "`#0%s`" kd)
let escaped tag = Md.plain (Printf.sprintf "`\"%s\"`" @@ String.escaped tag)

type pp = {
  self: Md.text ;
  data: ident -> Md.text ;
}

let rec md_jtype pp = function
  | Jany -> Md.emph "any"
  | Jself -> pp.self
  | Jnull -> Md.emph "null"
  | Jnumber -> Md.emph "number"
  | Jboolean -> Md.emph "boolean"
  | Jstring -> Md.emph "string"
  | Jtag tag -> escaped tag
  | Jkey kd -> key kd
  | Jindex kd -> index kd
  | Jdata id -> pp.data id
  | Joption js -> protect pp js @ Md.code "?"
  | Jtuple js -> Md.code "[" @ md_jlist pp "," js @ Md.code "]"
  | Junion js -> md_jlist pp "|" js
  | Jarray js -> protect pp js @ Md.code "[]"
  | Jrecord fjs -> Md.code "{" @ fields pp fjs @ Md.code "}"
  | Jassoc (id,js) ->
    Md.code "{[" @ key id @ Md.code "]:" @ md_jtype pp js @ Md.code "}"

and md_jlist pp sep js =
  Md.glue ~sep:(Md.plain sep)  (List.map (md_jtype pp) js)

and fields pp fjs =
  Md.glue ~sep:(Md.plain ",") @@
  List.map (fun (fd,js) ->
      escaped fd @
      match js with
      | Joption js -> Md.code ":?" @ md_jtype pp js
      | _ -> Md.code ":" @ md_jtype pp js
    ) fjs

and protect names js =
  match js with
  | Junion _ -> Md.code "(" @ md_jtype names js @ Md.code ")"
  | _ -> md_jtype names js

(* -------------------------------------------------------------------------- *)
(* --- Tags & Fields                                                      --- *)
(* -------------------------------------------------------------------------- *)

let md_tags ?(title="Tags") (tags : tagInfo list) =
  let header = Md.[
      plain title, Left;
      plain "Value", Left;
      plain "Description", Left
    ] in
  let row tg = [
    tg.tg_label ;
    escaped tg.tg_name ;
    tg.tg_descr ;
  ] in
  Md.{ caption = None ; header ; content = List.map row tags  }

let md_fields ?(title="Field") pp (fields : fieldInfo list) =
  let header = Md.[
      plain title, Left;
      plain "Format", Center;
      plain "Description", Left;
    ] in
  let row f =
    match f.fd_type with
    | Joption js -> [
        escaped (f.fd_name ^ "?") ;
        md_jtype pp js ;
        f.fd_descr ;
      ]
    | _ -> [
        escaped f.fd_name ;
        md_jtype pp f.fd_type ;
        f.fd_descr ;
      ]
  in
  Md.{ caption = None ; header ; content = List.map row fields }

(* -------------------------------------------------------------------------- *)
(* --- Printer                                                            --- *)
(* -------------------------------------------------------------------------- *)

let pp_jtype fmt js =
  let scope = Scope.create Kernel in
  visit_jtype (Scope.use scope) js ;
  let ns = Scope.resolve scope in
  let self = Md.emph "self" in
  let data id = Md.emph (IdMap.find id ns) in
  Markdown.pp_text fmt (md_jtype { data ; self } js)

(* -------------------------------------------------------------------------- *)
