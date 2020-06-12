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

module Md = Markdown

(* -------------------------------------------------------------------------- *)

type plugin = Kernel | Plugin of string
type package = { plugin: plugin; pkgname: string list }
type ident = { package: package; name: string }
type name = string list

let pp_plugin fmt = function
  | Kernel -> Format.pp_print_string fmt "Kernel"
  | Plugin p -> Format.fprintf fmt "Plugin %s" p

let pp_name fmt = function
  | [] -> ()
  | p::ps ->
    Format.pp_print_string fmt p ;
    List.iter (fun p ->
        Format.pp_print_char fmt '.' ;
        Format.pp_print_string fmt p ;
      ) ps

let pp_package fmt { plugin ; pkgname } =
  match plugin with
  | Kernel -> pp_name fmt pkgname
  | Plugin p -> Format.fprintf fmt "%s.%a" p pp_name pkgname

let pp_ident fmt { package = pkg ; name = id } =
  Format.fprintf fmt "%a.%s" pp_package pkg id

(* -------------------------------------------------------------------------- *)
(* --- Name Resolution                                                    --- *)
(* -------------------------------------------------------------------------- *)

module PkgMap =
  Map.Make(struct type t = package let compare = Stdlib.compare end)

module IdMap =
  Map.Make(struct type t = ident let compare = Stdlib.compare end)

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
  let ranked_name source { package = pkg ; name = id } k =
    let name = [id] in
    match k with
    | 0 -> name
    | 1 -> relative ~source ~target:pkg.plugin name
    | 2 -> relative ~source ~target:pkg.plugin (inpkg name pkg.pkgname)
    | 3 -> relative ~source ~target:pkg.plugin (pkg.pkgname @ name)
    | _ -> target pkg.plugin (pkg.pkgname @ name)

  type t = {
    source : plugin ;
    mutable clashes : bool ;
    mutable index : (name,(ident * int) list) Hashtbl.t ;
    mutable names : name IdMap.t ;
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
    match ranked_name scope.source id rk with
    | [a] when NameSet.mem a scope.reserved ->
      non_reserved scope id (succ rk)
    | ns -> ns , rk

  let push scope id rk =
    begin
      let name, rk = non_reserved scope id rk in
      scope.names <- IdMap.add id name scope.names ;
      let index = scope.index in
      match Hashtbl.find_opt index name with
      | None -> Hashtbl.add index name [id,rk]
      | Some idks ->
        if List.length idks = 1 then scope.clashes <- true ;
        Hashtbl.replace index name ((id,rk) :: idks)
    end

  let use scope id = push scope id 0

  let reserve_name scope name =
    assert (IdMap.is_empty scope.names) ;
    scope.reserved <- NameSet.add name scope.reserved

  let reserve_ident scope { name } = reserve_name scope name

  let rec resolve scope =
    if not scope.clashes then scope.names else
      begin
        let index = scope.index in
        scope.index <- Hashtbl.create 0 ;
        scope.clashes <- false ;
        Hashtbl.iter
          (fun _name idks ->
             match idks with
             | [id,rk] -> push scope id rk
             | idks ->
               List.iter (fun (id,rk) -> push scope id (succ rk)) idks
          ) index ;
        resolve scope
      end

  let name_of ns id =
    try String.concat "." (IdMap.find id ns)
    with Not_found -> "?"

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
  | Jkind of string
  | Joption of jtype
  | Jassoc of string * jtype
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
  | D_type of jtype
  | D_record of fieldInfo list
  | D_request of requestInfo

type declInfo = {
  d_ident : ident;
  d_kind : declKindInfo;
  d_title : Markdown.text;
  d_descr : Markdown.block;
}

type packageInfo = {
  d_package : package;
  d_content : declInfo list;
}

(* -------------------------------------------------------------------------- *)
(* --- Visitors                                                           --- *)
(* -------------------------------------------------------------------------- *)

let rec visit_jtype fn = function
  | Jany | Jself | Jnull | Jboolean | Jnumber
  | Jstring | Jkind _ | Jtag _ -> ()
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
  | D_signal -> ()
  | D_type js -> visit_jtype f js
  | D_record fds -> List.iter (visit_field f) fds
  | D_request rq -> visit_request f rq

let visit_decl f { d_kind } = visit_dkind f d_kind

let visit_package_def f { d_content } =
  List.iter (fun { d_ident } -> f d_ident) d_content

let visit_package_used f { d_content } =
  List.iter (visit_decl f) d_content

let package_resolve ?(keywords=[]) pkg =
  let scope = Scope.create pkg.d_package.plugin in
  List.iter (Scope.reserve_name scope) keywords ;
  visit_package_def (Scope.reserve_ident scope) pkg ;
  visit_package_used (Scope.use scope) pkg ;
  IdMap.map (String.concat "_") (Scope.resolve scope)

(* -------------------------------------------------------------------------- *)
(* --- Server API                                                         --- *)
(* -------------------------------------------------------------------------- *)

let ident_re = Str.regexp "^\\([a-z0-9]+\\.\\)*[a-zA-Z0-9]+$"

let identFor ?plugin name =
  if not (Str.string_match ident_re name 0) then
    failwith
      (Printf.sprintf "Invalid identifier %S (use \"abc.def.fooBar\")" name) ;
  let plugin = match plugin with None -> Kernel | Some p -> Plugin p in
  let path = String.split_on_char '.' name in
  let pkgname , name = match List.rev path with
    | [] -> failwith (Printf.sprintf "Inconsistent name %S" name)
    | a :: ps -> List.map String.lowercase_ascii (List.rev ps) , a
  in { package = { plugin ; pkgname } ; name }

let packages = ref PkgMap.empty

let declare ?plugin ~id ~title ?(descr=[]) decl =
  let ident = identFor ?plugin id in
  let pkg = ident.package in
  let decl = { d_ident=ident ; d_title=title ; d_descr=descr ; d_kind=decl } in
  let content = try PkgMap.find pkg !packages with Not_found -> [] in
  packages := PkgMap.add pkg (decl::content) !packages ; ident

let iter f =
  PkgMap.iter
    (fun d_package d_content -> f { d_package ; d_content })
    !packages

(* -------------------------------------------------------------------------- *)
(* --- JSON To MarkDown                                                   --- *)
(* -------------------------------------------------------------------------- *)

let escaped tag = Md.code (Printf.sprintf "\"%s\"" @@ String.escaped tag)

type pp = {
  self: Md.text ;
  data: ident -> Md.text ;
  kind: string -> Md.text ;
}

let rec md_jtype pp = function
  | Jany -> Md.emph "any"
  | Jself -> pp.self
  | Jnull -> Md.emph "null"
  | Jnumber -> Md.emph "number"
  | Jboolean -> Md.emph "boolean"
  | Jstring -> Md.emph "string"
  | Jtag tag -> escaped tag
  | Jkind kd -> pp.kind kd
  | Jdata id -> pp.data id
  | Joption js -> protect pp js @ Md.code "?"
  | Jtuple js -> Md.code "[" @ md_jlist pp "," js @ Md.code "]"
  | Junion js -> md_jlist pp "|" js
  | Jarray js -> protect pp js @ Md.code "[]"
  | Jrecord fjs -> Md.code "{" @ fields pp fjs @ Md.code "}"
  | Jassoc (id,js) ->
    Md.code "{[" @ pp.kind id @ Md.code "]:" @ md_jtype pp js @ Md.code "}"

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

let pp_jtype fmt js =
  let scope = Scope.create Kernel in
  visit_jtype (Scope.use scope) js ;
  let ns = Scope.resolve scope in
  let self = Md.emph "self" in
  let kind id = Md.code (Printf.sprintf "#%s" id) in
  let data id = Md.emph (Scope.name_of ns id) in
  Markdown.pp_text fmt (md_jtype { kind ; data ; self } js)

(* -------------------------------------------------------------------------- *)
