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
type path = string list
type ident = private { plugin: plugin; package: path; name: string; }

type jtype =
  | Jany
  | Jnull
  | Jboolean
  | Jnumber
  | Jstring
  | Jtag of string (** Enum constant tag *)
  | Jkey of string (** Kind of numbers used for indexing *)
  | Jindex of string (** Kind of strings used for indexing *)
  | Joption of jtype (** Value or 'null' *)
  | Jassoc of string * jtype (** Dictionary for kind of ids *)
  | Jarray of jtype
  | Jtuple of jtype list
  | Junion of jtype list
  | Jrecord of (string * jtype) list
  | Jdata of ident
  | Jself (** for (simply) recursive types *)

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
  | D_type of jtype
  | D_enum of tagInfo list
  | D_record of fieldInfo list
  | D_request of requestInfo

type declInfo = {
  d_ident : ident;
  d_descr : Markdown.elements;
  d_kind : declKindInfo;
}

type packageInfo = {
  d_plugin : plugin;
  d_package : path;
  d_userdoc : Markdown.elements;
  d_content : declInfo list;
}

(* -------------------------------------------------------------------------- *)
(* --- Pretty Printers                                                    --- *)
(* -------------------------------------------------------------------------- *)

val pp_plugin : Format.formatter -> plugin -> unit
val pp_ident : Format.formatter -> ident -> unit
val pp_jtype : Format.formatter -> jtype -> unit

(* -------------------------------------------------------------------------- *)
(* --- Names Resolution                                                   --- *)
(* -------------------------------------------------------------------------- *)

module IdMap : Map.S with type key = ident

module Scope :
sig
  type t
  val create : plugin -> t
  val reserve_name : t -> string -> unit (** Must _not_ be call after [use] *)
  val reserve_ident : t -> ident -> unit (** Must _not_ be call after [use] *)
  val resolve : t -> string IdMap.t
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

(* -------------------------------------------------------------------------- *)
(* --- Server API                                                         --- *)
(* -------------------------------------------------------------------------- *)

type package

val package :
  ?plugin:string ->
  ?title:string ->
  ?descr:Markdown.elements ->
  ?readme:string ->
  name:string ->
  unit -> package

(**
   Register the declaration in the Server API.
   This is only way to obtain identifiers.
   This ensures identifiers are declared before being used.
*)
val declare :
  package:package ->
  name:string ->
  ?descr:Markdown.elements ->
  declKindInfo ->
  unit

(**
   Same as [declare] but returns the associated identifier.
*)
val declare_id :
  package:package ->
  name:string ->
  ?descr:Markdown.elements ->
  declKindInfo ->
  ident

(**
   Declare a new type and returns its alias.
   Same as [Jdata (declare_id ~package ~name (D_type js))]`
*)
val datatype :
  package:package ->
  name:string ->
  ?descr:Markdown.elements ->
  jtype -> jtype

(**
   Replace the declaration for the given name in the package.
*)
val update :
  package:package ->
  name:string ->
  declKindInfo ->
  unit

val iter : (packageInfo -> unit) -> unit

(** Assigns non-classing names for each identifier. *)
val resolve : ?keywords: string list -> packageInfo -> string IdMap.t

val name_of_pkginfo : packageInfo -> string
val name_of_package : package -> string
val name_of_ident : ident -> string

(* -------------------------------------------------------------------------- *)
(* --- Markdown Generation                                                --- *)
(* -------------------------------------------------------------------------- *)

type pp = {
  self: Markdown.text ;
  data: ident -> Markdown.text ;
}

val escaped : string -> Markdown.text

val md_jtype : pp -> jtype -> Markdown.text
val md_tags : ?title:string -> tagInfo list -> Markdown.table
val md_fields : ?title:string -> pp -> fieldInfo list -> Markdown.table

(* -------------------------------------------------------------------------- *)
