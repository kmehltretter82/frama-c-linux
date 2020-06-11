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

type plugin = Kernel | Plugin of string
type package = { plugin: plugin; pkgname: string list }
type ident = package * string
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

let pp_ident fmt (pkg,id) =
  Format.fprintf fmt "%a.%s" pp_package pkg id

(* -------------------------------------------------------------------------- *)
(* --- Name Resolution                                                    --- *)
(* -------------------------------------------------------------------------- *)

module PkgMap =
  Map.Make(struct type t = package let compare = Stdlib.compare end)

module IdMap =
  Map.Make(struct type t = ident let compare = Stdlib.compare end)

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
  let ranked_name source (pkg,id) k =
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
  }

  let create source = {
    source ;
    index = Hashtbl.create 0 ;
    clashes = false ;
    names = IdMap.empty ;
  }

  let push scope id rk =
    begin
      let name = ranked_name scope.source id rk in
      scope.names <- IdMap.add id name scope.names ;
      let index = scope.index in
      match Hashtbl.find_opt index name with
      | None -> Hashtbl.add index name [id,rk]
      | Some idks ->
        if List.length idks = 1 then scope.clashes <- true ;
        Hashtbl.replace index name ((id,rk) :: idks)
    end

  let use scope id = push scope id 0

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

type json =
  | Jany
  | Jnull
  | Jboolean
  | Jnumber
  | Jstring
  | Jtag of string
  | Jkind of string
  | Joption of json
  | Jassoc of string * json
  | Jarray of json
  | Jtuple of json list
  | Junion of json list
  | Jrecord of (string * json) list
  | Jdata of ident

let rec iter fn = function
  | Jany | Jnull | Jboolean | Jnumber
  | Jstring | Jkind _ | Jtag _ -> ()
  | Joption js | Jassoc(_,js)  | Jarray js -> iter fn js
  | Jtuple js | Junion js -> List.iter (iter fn) js
  | Jrecord fjs -> List.iter (fun (_,js) -> iter fn js) fjs
  | Jdata id -> fn id

(* -------------------------------------------------------------------------- *)
(* --- JSON MarkDown                                                      --- *)
(* -------------------------------------------------------------------------- *)

module Md = Markdown

let escaped tag = Md.code (Printf.sprintf "\"%s\"" @@ String.escaped tag)

type pp = {
  data: ident -> Md.text ;
  kind: string -> Md.text ;
}

let rec text pp = function
  | Jany -> Md.emph "any"
  | Jnull -> Md.emph "null"
  | Jnumber -> Md.emph "number"
  | Jboolean -> Md.emph "boolean"
  | Jstring -> Md.emph "string"
  | Jtag tag -> escaped tag
  | Jkind kd -> pp.kind kd
  | Jdata id -> pp.data id
  | Joption js -> protect pp js @ Md.code "?"
  | Jtuple js -> Md.code "[" @ list pp "," js @ Md.code "]"
  | Junion js -> list pp "|" js
  | Jarray js -> protect pp js @ Md.code "[]"
  | Jrecord fjs -> Md.code "{" @ fields pp fjs @ Md.code "}"
  | Jassoc (id,js) ->
    Md.code "{[" @ pp.kind id @ Md.code "]:" @ text pp js @ Md.code "}"

and list pp sep js = Md.glue ~sep:(Md.plain sep)  (List.map (text pp) js)

and fields pp fjs =
  Md.glue ~sep:(Md.plain ",") @@
  List.map (fun (fd,js) ->
      escaped fd @
      match js with
      | Joption js -> Md.code ":?" @ text pp js
      | _ -> Md.code ":" @ text pp js
    ) fjs

and protect names js =
  match js with
  | Junion _ -> Md.code "(" @ text names js @ Md.code ")"
  | _ -> text names js

let pretty fmt js =
  let scope = Scope.create Kernel in
  iter (Scope.use scope) js ;
  let ns = Scope.resolve scope in
  let kind id = Md.code (Printf.sprintf "#%s" id) in
  let data id = Md.emph (Scope.name_of ns id) in
  Markdown.pp_text fmt (text { kind ; data } js)

(* -------------------------------------------------------------------------- *)
