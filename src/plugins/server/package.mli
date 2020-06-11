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

val pp_plugin : Format.formatter -> plugin -> unit
val pp_package : Format.formatter -> package -> unit
val pp_ident : Format.formatter -> ident -> unit
val pp_name : Format.formatter -> name -> unit

module PkgMap : Map.S with type key = package
module IdMap : Map.S with type key = ident

module Scope :
sig
  type t
  val create : plugin -> t
  val resolve : t -> name IdMap.t
  val name_of : name IdMap.t -> ident -> string
  val use : t -> ident -> unit
end

type json =
  | Jany
  | Jnull
  | Jboolean
  | Jnumber
  | Jstring
  | Jtag of string (** Enum constant tag *)
  | Jkind of string (** Kind of ids (actually strings) *)
  | Joption of json (** Value or 'null' *)
  | Jassoc of string * json (** Dictionary for kind of ids *)
  | Jarray of json
  | Jtuple of json list
  | Junion of json list
  | Jrecord of (string * json) list
  | Jdata of ident

val iter : (ident -> unit) -> json -> unit
val pretty : Format.formatter -> json -> unit

type pp = {
  data: ident -> Markdown.text ;
  kind: string -> Markdown.text ;
}

val text : pp -> json -> Markdown.text

(* -------------------------------------------------------------------------- *)
