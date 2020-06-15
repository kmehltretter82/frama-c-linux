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
(** JSON Encoding Documentation *)
(* -------------------------------------------------------------------------- *)

type t

val text : t -> Markdown.text

(** The provided synopsis must be very short, to fit in one line.
    Extended definition, like record fields and such, must be detailed in
    the description block. *)
val publish :
  page:Server_doc.page -> name:string -> descr:Markdown.text ->
  synopsis:t ->
  ?details:Markdown.elements ->
  ?generated:(unit -> Markdown.elements) ->
  unit -> t

val unit : t
val any : t
val int : t (* small, non-decimal, number *)
val ident : t (* integer of string *)
val string : t
val number : t
val boolean : t

val tag : string -> t
val array : t -> t
val tuple : t list -> t
val union : t list -> t
val option : t -> t
val record : (string * t) list -> t
val data : string -> Markdown.href -> t

type tag = {
  tag_name : string ;
  tag_label : Markdown.text ;
  tag_descr : Markdown.text ;
}

(** Syntactic definition: LEFT := RIGHT *)
val define : Markdown.text -> Markdown.text -> Markdown.block_element

(** Builds a table with tags description.
    The [~title] is applied to the tag name column
    (shall be capitalized, defaults to ["Tag"]). *)
val tags : ?title:string -> tag list -> Markdown.element

type field = { fd_name : string ; fd_syntax : t ; fd_descr : Markdown.text }

(** Builds a table with fields description.
    The [~title] is applied to the field name column
    (shall be capitalized, defaults to ["Field"]). *)
val fields : ?title:string -> field list -> Markdown.element

(* -------------------------------------------------------------------------- *)
