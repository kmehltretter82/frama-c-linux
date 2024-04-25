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

open Cil_types

exception Error of Cil_types.location * string
exception Unbound of string

(** For the three functions below, [env] can be used to specify which
    logic labels are parsed. By default, only [Here] is accepted. All
    the C labels inside the function are also  accepted, regardless of
    [env]. [loc] is used as the source for the beginning of the string.
    All three functions may raise {!Logic_interp.Error} or
    {!Parsing.Parse_error}. *)

val code_annot : kernel_function -> stmt -> string -> code_annotation
val term_lval :
  kernel_function -> ?loc:location -> ?env:Logic_typing.Lenv.t -> string ->
  Cil_types.term_lval
val term :
  kernel_function -> ?loc:location -> ?env:Logic_typing.Lenv.t -> string ->
  Cil_types.term
val predicate :
  kernel_function -> ?loc:location -> ?env:Logic_typing.Lenv.t -> string ->
  Cil_types.predicate
