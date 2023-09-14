(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

(** Utilities to pretty print source with located Ast elements *)

open Cil_types

(** The kind of AST declarations that can be printed. *)
type scope =
  | SEnum of enuminfo
  | SComp of compinfo
  | SType of typeinfo
  | SGlobal of varinfo
  | SFunction of kernel_function

(** Prints a concise label of the scope *)
val pp_scope : Format.formatter -> scope -> unit

module Scope: Datatype.S_with_collections with type t = scope

(** The kind of object that can be selected in the source viewer. *)
type localizable =
  | PStmt of (kernel_function * stmt)
  (** Full statement (with attributes, annotations, etc.) *)
  | PStmtStart of (kernel_function * stmt)
  (** Naked statement (only skind, without attributes, annotations, etc.) *)
  | PLval of (kernel_function option * kinstr * lval)
  (** L-Values *)
  | PExp of (kernel_function option * kinstr * exp)
  (** Non l-value expressions *)
  | PTermLval of (kernel_function option * kinstr * Property.t * term_lval)
  (** Term l-values inside properties *)
  | PVDecl of (kernel_function option * kinstr * varinfo)
  (** Declaration and definition of variables and function. Check the type
      of the varinfo to distinguish between the various possibilities.
      If the varinfo is a global or a local, the kernel_function is the
      one in which the variable is declared. The [kinstr] argument is given
      for local variables with an explicit initializer. *)
  | PGlobal of global
  (** Global definitions except global variables and functions. *)
  | PIP of Property.t
  | PType of typ

(** Name (or category). *)
val label: localizable -> string

(** Name (or category). *)
val glabel: global -> string


(** Prints the global declaration of the scope. *)
val pp_declaration : Format.formatter -> scope -> unit

(** Prints the global definition of the scope. *)
val pp_definition : Format.formatter -> scope -> unit

(** Prints the signature of the localizable. *)
val pp_localizable: Format.formatter -> localizable -> unit

(** Debugging. *)
val pp_debug: Format.formatter -> localizable -> unit

module Localizable: Datatype.S_with_collections with type t = localizable

val scope_of_type : typ -> scope option
val scope_of_global : global -> scope option
val scope_of_localizable : localizable -> scope option

val loc_of_scope : scope -> location
val name_of_scope : scope -> string
val declaration_of_scope : scope -> global
val definition_of_scope : scope -> global

val localizable_of_global : global -> localizable
val localizable_of_kf : kernel_function -> localizable

val kf_of_localizable : localizable -> kernel_function option
val ki_of_localizable : localizable -> kinstr
val varinfo_of_localizable : localizable -> varinfo option
val typ_of_localizable: localizable -> typ option
val loc_of_localizable : localizable -> location
(** Might return [Location.unknown] *)

val loc_to_localizable: ?precise_col:bool -> Filepath.position -> localizable option
(** return the (hopefully) most precise localizable that contains the given
    Filepath.position. If [precise_col] is [true], takes the column number into
    account (possibly a more precise, but costly, result).
    @since 24.0-Chromium *)

module type Tag =
sig
  val tag : localizable -> string
end

module type S_pp =
sig
  include Printer_api.S_pp
  val with_unfold_precond : (stmt -> bool) ->
    (Format.formatter -> 'a -> unit) ->
    (Format.formatter -> 'a -> unit)
end

module Make(T : Tag) : S_pp

(* -------------------------------------------------------------------------- *)
