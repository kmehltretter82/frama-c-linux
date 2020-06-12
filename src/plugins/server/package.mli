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
(* --- Constituant of the Server API                                      --- *)
(* -------------------------------------------------------------------------- *)

type plugin = Kernel | Plugin of string
type package = { plugin: plugin; pkgname: string list }
type ident = package * string
type name = string list

type jtype =
  | Jany
  | Jnull
  | Jboolean
  | Jnumber
  | Jstring
  | Jtag of string (** Enum constant tag *)
  | Jkind of string (** Kind of ids (actually strings) *)
  | Joption of jtype (** Value or 'null' *)
  | Jassoc of string * jtype (** Dictionary for kind of ids *)
  | Jarray of jtype
  | Jtuple of jtype list
  | Junion of jtype list
  | Jrecord of (string * jtype) list
  | Jdata of ident

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
  d_content : declInfo Bag.t;
}

(* -------------------------------------------------------------------------- *)
(* --- Pretty Printers                                                    --- *)
(* -------------------------------------------------------------------------- *)

val pp_plugin : Format.formatter -> plugin -> unit
val pp_package : Format.formatter -> package -> unit
val pp_ident : Format.formatter -> ident -> unit
val pp_name : Format.formatter -> name -> unit
val pp_jtype : Format.formatter -> jtype -> unit

(* -------------------------------------------------------------------------- *)
(* --- Imports Resolution                                                 --- *)
(* -------------------------------------------------------------------------- *)

module PkgMap : Map.S with type key = package
module IdMap : Map.S with type key = ident

module Scope :
sig
  type t
  val create : plugin -> t
  val reserve_name : t -> string -> unit (** Must _not_ be call after [use] *)
  val reserve_ident : t -> ident -> unit (** Must _not_ be call after [use] *)
  val resolve : t -> name IdMap.t
  val name_of : name IdMap.t -> ident -> string
  val use : t -> ident -> unit
end

val visit_jtype : (ident -> unit) -> jtype -> unit
val visit_field: (ident -> unit) -> fieldInfo -> unit
val visit_param: (ident -> unit) -> paramInfo -> unit
val visit_request: (ident -> unit) -> requestInfo -> unit
val visit_dkind: (ident -> unit) -> declKindInfo -> unit
val visit_decl: (ident -> unit) -> declInfo -> unit
val visit_package_def: (ident -> unit) -> packageInfo -> unit
val visit_package_used: (ident -> unit) -> packageInfo -> unit

(** Assigns non-classing names for each identifier. *)
val package_resolve : ?keywords: string list -> packageInfo -> string IdMap.t

(* -------------------------------------------------------------------------- *)
(* --- Markdown Generation                                                --- *)
(* -------------------------------------------------------------------------- *)

type pp = {
  data: ident -> Markdown.text ;
  kind: string -> Markdown.text ;
}

val md_jtype : pp -> jtype -> Markdown.text

(* -------------------------------------------------------------------------- *)
