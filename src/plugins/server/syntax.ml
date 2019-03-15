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

(* -------------------------------------------------------------------------- *)

module STR = Transitioning.String
module Senv = Server_parameters

let check_plugin plugin name =
  let p = STR.lowercase_ascii plugin in
  let n = STR.lowercase_ascii name in
  let k = String.length plugin in
  if not (String.length name > k &&
          String.sub n 0 k = p &&
          String.get n k = '.')
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

let format { text } = text
let protect a =
  if a.atomic then a.text else Markdown.(rm "(" <+> a.text <+> rm ")")

let publish ~page ~name ~descr ~synopsis ?(details = Markdown.empty) () =
  check_name name ;
  check_page page name ;
  let id = Printf.sprintf "data-%s" name in
  let title = Printf.sprintf "`DATA` %s" name in
  let format = ref Markdown.nil in
  let syntax = Markdown.fmt_block (fun fmt ->
      Format.fprintf fmt "> %a ::= %a"
        Markdown.pp_text !format
        Markdown.pp_text synopsis.text
    ) in
  let content = Markdown.( par descr </> syntax </> details ) in
  let href = Doc.publish ~page ~name:id ~title ~index:[name] content [] in
  let link_title = Printf.sprintf "_%s_" name in
  let link = Markdown.href ~title:link_title href in
  format := link ; atom @@ link

let any = atom @@ Markdown.it "any"
let int = atom @@ Markdown.it "int"
let ident = atom @@ Markdown.it "ident"
let string = atom @@ Markdown.it "string"
let number = atom @@ Markdown.it "number"
let boolean = atom @@ Markdown.it "boolean"

let null = atom @@ Markdown.tt "null" (* really « tt » *)

let escaped name = Markdown.tt @@ Printf.sprintf "'%s'" @@ String.escaped name

let tag name = atom @@ escaped name

let array a = atom @@ Markdown.(tt "[" <+> protect a <+> tt ",…]")

let tuple ts =
  atom @@ Markdown.(tt "["
                    <+> glue ~sep:(raw " `,` ") (List.map protect ts) <+>
                    tt "]")

let union ts = flow @@ Markdown.(glue ~sep:(raw " | ") (List.map protect ts))

let option t = atom @@ Markdown.(protect t <@> tt "?")

let field (a,t) = Markdown.( escaped a <+> tt ":" <+> t.text )

let record fds =
  let fields =
    if fds = [] then Markdown.rm "…" else
      Markdown.(glue ~sep:(raw " `;` ") (List.map field fds))
  in atom @@ Markdown.(tt "{" <+> fields <+> tt "}")

type field = {
  name : string ;
  syntax : t ;
  descr : Markdown.text ;
}

let fields ~kind (fds : field list) =
  let c_field = `Left kind in
  let c_format = `Center "Format" in
  let c_descr = `Left "Description" in
  Markdown.table [ c_field ; c_format ; c_descr ]
    begin
      List.map
        (fun f ->
           [ Markdown.tt f.name ; format f.syntax ; f.descr ])
        fds
    end

(* -------------------------------------------------------------------------- *)
