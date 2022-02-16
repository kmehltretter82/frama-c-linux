(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2021                                               *)
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

open Cil_types

val case_globals :
  default:(unit -> 'a) ->
  ?builtin:(varinfo -> 'a) ->
  ?fc_compiler_builtin:(varinfo -> 'a) ->
  ?rtl_symbol:(global -> 'a) ->
  ?fc_stdlib_generated:(varinfo -> 'a) ->
  ?var_fun_decl:(varinfo -> 'a) ->
  ?var_init:(varinfo -> 'a) ->
  ?var_def:(varinfo -> init -> 'a) ->
  fun_def:(fundec -> 'a) ->
  global -> 'a
(** Function to descend into the root of the ast according to the various cases
    relevant for E-ACSL. Each of the named argument corresponds to the function
    to be applied in the corresponding case. The [default] case is used if any
    optional argument is not given
    - [builtin] is the case for C builtins
    - [fc_builtin_compiler] is the case for frama-c or compiler builtins
    - [rtl_symbol] is the case for any global coming from the runtime library
    - [fc_stdlib_generated] is the case for frama-c or standard library
      generated functions
    - [var_fun_decl] is the case for variables or functions declarations
    - [var_init] is the case for variable definition wihtout an initialization
      value
    - [var_def] is the case for variable definitions with an initialization
      value
    - [fun_def] is the case for function definition. *)

(** Visitor for managing the root of the AST, on the globals level, with the
    cases that are relevant to E-ACSL. Each case is handled by a method of
    the visitor. The cases are similar, and similarly named as the ones of
    the function [case_globals]. *)
class visitor :
  object
    inherit Visitor.frama_c_inplace
    method private default: unit -> global list Cil.visitAction
    method builtin: varinfo -> global list Cil.visitAction
    method fc_compiler_builtin: varinfo -> global list Cil.visitAction
    method rtl_symbol: global -> global list Cil.visitAction
    method fc_stdlib_generated: varinfo -> global list Cil.visitAction
    method var_fun_decl: varinfo -> global list Cil.visitAction
    method var_init: varinfo -> global list Cil.visitAction
    method var_def: varinfo -> init -> global list Cil.visitAction
    method fun_def: fundec -> global list Cil.visitAction
  end
