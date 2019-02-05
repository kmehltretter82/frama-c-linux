(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

module Senv = Server_parameters

(* -------------------------------------------------------------------------- *)
(* --- Request Registry                                                   --- *)
(* -------------------------------------------------------------------------- *)

type json = Data.json
type kind = [ `GET | `SET | `EXEC ]

module type Input =
sig
  type t
  val descr : Markdown.text
  val of_json : json -> t
end

module type Output =
sig
  type t
  val descr : Markdown.text
  val to_json : t -> json
end

module type RequestInfo =
sig
  type input
  type output
  val page : Doc.page
  val name : string
  val kind : kind
  val descr : Markdown.text
  val details : Markdown.section list
  val process : input -> output
end

module type S =
sig
  include RequestInfo
  val href : Markdown.href
  val process_json : json -> json
end

(* -------------------------------------------------------------------------- *)
(* --- Sanity Checks                                                      --- *)
(* -------------------------------------------------------------------------- *)

module STR = Transitioning.String

let re_get = Str.regexp_case_fold "\\(GET\\|PRINT\\)"
let re_set = Str.regexp_string_case_fold "SET"
let re_exec = Str.regexp_string_case_fold "EXEC"

let wpage = Senv.register_warn_category "inconsistent-page"
let wkind = Senv.register_warn_category "inconsistent-kind"

let check_plugin plugin name =
  let p = STR.lowercase_ascii plugin in
  let n = STR.lowercase_ascii name in
  let k = String.length plugin in
  if not (String.length name > k &&
          String.sub n 0 k = p &&
          String.get n k = '.')
  then
    Senv.warning ~wkey:wpage
      "Request '%s' shall be named « %s.* »"
      name (STR.capitalize_ascii plugin)

let check_page page name =
  match Doc.chapter page with
  | `Kernel -> check_plugin "kernel" name
  | `Plugin plugin -> check_plugin plugin name
  | `Protocol ->
    Senv.warning ~wkey:wkind
      "Request '%s' shall not be published in protocol pages" name

let check_kind kind name =
  let re = match kind with
    | `GET -> re_get
    | `SET -> re_set
    | `EXEC -> re_exec
  in try ignore (Str.search_forward re name 0) with Not_found ->
    Senv.warning "Request '%s' shall be named « *%s* »"
      name (Main.string_of_kind kind
            |> STR.lowercase_ascii
            |> STR.capitalize_ascii)

(* -------------------------------------------------------------------------- *)
(* --- Registration                                                       --- *)
(* -------------------------------------------------------------------------- *)

module Register
    (Input : Input)
    (Output : Output)
    (Rq : RequestInfo with type input = Input.t
                       and type output = Output.t)
=
struct
  include Rq

  let process_json js =
    js |> Input.of_json |> Rq.process |> Output.to_json

  let href =
    let kind = Main.string_of_kind Rq.kind in
    let title =  Printf.sprintf "`%s` %s" kind Rq.name in
    let synopsis =
      Markdown.table
        [ `Center "Input" ; `Center "Output" ; `Left "Description" ]
        [[ Input.descr ; Output.descr ; Rq.descr ]]
    in
    Doc.publish Rq.page ~index:[Rq.name] ~title synopsis Rq.details

  let () =
    check_page Rq.page Rq.name ;
    check_kind Rq.kind Rq.name ;
    Main.register Rq.kind Rq.name process_json

end

(* -------------------------------------------------------------------------- *)
