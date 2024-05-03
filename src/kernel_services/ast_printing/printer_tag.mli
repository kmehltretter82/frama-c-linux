(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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
type declaration =
  | SEnum of enuminfo
  | SComp of compinfo
  | SType of typeinfo
  | SGlobal of varinfo
  | SFunction of kernel_function

(** Prints a concise label of the declaration. *)
val pp_declaration : Format.formatter -> declaration -> unit

module Declaration: Datatype.S_with_collections with type t = declaration

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

(** Prints the global declaration of the declaration. *)
val pp_signature : Format.formatter -> declaration -> unit

(** Prints the global definition of the declaration. *)
val pp_definition : Format.formatter -> declaration -> unit

(** Prints the signature of the localizable. *)
val pp_localizable: Format.formatter -> localizable -> unit

(** Debugging. *)
val pp_debug: Format.formatter -> localizable -> unit

module Localizable: Datatype.S_with_collections with type t = localizable

(** {2 Declaration of Localizable}

    Localizable items are always printed under a certain global scope
    identified by a declaration that can be retrieved from
    {!declaration_of_type}, {!declaration_of_global}, {!declaration_of_property}
    and {!declaration_of_localizable} functions below.

    Moreover, each declared item can be identified in two different ways: a
    declaration scope and its own localizable inside this scope. Functions
    {!localizable_of_kf}, {!localizable_of_global} and
    {!localizable_of_declaration} can be used to obtain the self-localization of
    declarations.

    Differently, some localizable refers to some global declaration, eg.
    a variable or a function inside an expression or the compound name
    of a type. In such a case, functions {!definition_of_type} and
    {!definition_of_localizable} return the localization of the referenced
    declaration. It is returned as a localization to the associated declaration,
    whose scope can be obtained in turn with {!declaration_of_localizable}.

*)

val declaration_of_type : typ -> declaration option
val declaration_of_global : global -> declaration option
val declaration_of_property : Property.t -> declaration option
val declaration_of_localizable : localizable -> declaration option

val definition_of_type : typ -> localizable option
val definition_of_localizable : localizable -> localizable option

val loc_of_declaration : declaration -> location

val name_of_type : typ -> string option
val name_of_global : global -> string option
val name_of_declaration : declaration -> string
val name_of_localizable : localizable -> string option

val signature_of_declaration : declaration -> global
val definition_of_declaration : declaration -> global

val localizable_of_kf : kernel_function -> localizable
val localizable_of_global : global -> localizable
val localizable_of_stmt : stmt -> localizable
val localizable_of_declaration : declaration -> localizable

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

module Make(_ : Tag) : S_pp

(* -------------------------------------------------------------------------- *)
