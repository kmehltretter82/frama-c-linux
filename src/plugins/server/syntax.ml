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

let check_plugin plugin name =
  let p = String.lowercase_ascii plugin in
  let n = String.lowercase_ascii name in
  let k = String.length plugin in
  if not (String.length name > k &&
          String.sub n 0 k = p &&
          String.get n k = '-')
  then
    Senv.warning ~wkey:Senv.wpage
      "Data %S shall be named « %s-* »"
      name plugin

let check_page page name =
  match Doc.chapter page with
  | `Kernel -> ()
  | `Plugin plugin -> check_plugin plugin name
  | `Protocol -> check_plugin "server" name

let re_name = Str.regexp "[a-z0-9-]+$"

let check_name name =
  if not (Str.string_match re_name name 0) then
    Senv.warning ~wkey:Senv.wname
      "Data name %S is not a dash-separated list of lowercase identifiers" name

(* -------------------------------------------------------------------------- *)

type t = { atomic:bool ; text:Markdown.text }

let atom md = { atomic=true ; text=md }
let flow md = { atomic=false ; text=md }
let text { text } = text

let protect a =
  if a.atomic then a.text else Markdown.(plain "(" @ a.text @ plain ")")

let define left right =
  Markdown.(Block_quote [Block[Text ( left @ plain ":=" @ right )]])

let publish ~page ~name ~descr ~synopsis ?(details = []) ?generated () =
  check_name name ;
  check_page page name ;
  let id = Printf.sprintf "data-%s" name in
  let title = Printf.sprintf "`DATA` %s" name in
  let index = [ Printf.sprintf "%s (`DATA`)" name ] in
  let dref = Doc.href page id in
  let dlink = Markdown.href ~text:(Markdown.emph name) dref in
  let data = Markdown.(plain "<" @ dlink @ plain ">") in
  let contents = Markdown.(Block(
      [ Text descr ; define data synopsis.text ]
    )) :: details in
  let _href = Doc.publish ~page ~name:id ~title ~index ~contents ?generated ()
  in atom dlink

(* -------------------------------------------------------------------------- *)

let unit = atom @@ Markdown.code "null"
let any = atom @@ Markdown.emph "any"
let int = atom @@ Markdown.emph "int"
let ident = atom @@ Markdown.emph "ident"
let string = atom @@ Markdown.emph "string"
let number = atom @@ Markdown.emph "number"
let boolean = atom @@ Markdown.emph "boolean"
let data name dref = atom @@ Markdown.href ~text:(Markdown.emph name) dref

let escaped name =
  Markdown.code (Printf.sprintf "\"%s\"" @@ String.escaped name)

let tag name = atom @@ escaped name
let array a = atom @@ Markdown.(code "[" @ protect a @ code  ", … ]")

let tuple ts =
  atom @@
  Markdown.(
    code "[" @
    glue ~sep:(code ",") (List.map protect ts) @
    code "]"
  )

let union ts = flow @@ Markdown.(glue ~sep:(plain "|") (List.map protect ts))

let option t = atom @@ Markdown.(protect t @ code "?")

(* -------------------------------------------------------------------------- *)

type tag = {
  tag_name : string ;
  tag_label : Markdown.text ;
  tag_descr : Markdown.text ;
}

let tags ?(title="Tag") (tgs : tag list) =
  let open Markdown in
  let header = [
    plain title, Left;
    plain "Value", Left;
    plain "Description", Left
  ] in
  let row tg = [ tg.tag_label ; escaped tg.tag_name ; tg.tag_descr ] in
  Markdown.Table {
    caption = None ; header ; content = List.map row tgs ;
  }

(* -------------------------------------------------------------------------- *)

let mfield (a,t) = Markdown.( escaped a @ code ":" @ t.text )

let record fds =
  let fields =
    if fds = [] then Markdown.plain "…" else
      Markdown.(glue ~sep:(code ";") (List.map mfield fds))
  in atom @@ Markdown.(code "{" @ fields @ code "}")

type field = {
  fd_name : string ;
  fd_syntax : t ;
  fd_descr : Markdown.text ;
}

let fields ?(title="Field") (fds : field list) =
  let open Markdown in
  let header = [
    plain title, Left;
    plain "Format", Center;
    plain "Description", Left
  ] in
  let row f = [ escaped f.fd_name ; f.fd_syntax.text ; f.fd_descr ] in
  Markdown.Table {
    caption = None ; header ; content = List.map row fds ;
  }

(* -------------------------------------------------------------------------- *)
