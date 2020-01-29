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

open Cil_types
open Logic_typing
open Logic_ptree

type extension

type extension_preprocessor =
  lexpr list -> lexpr list
type extension_typer =
  typing_context -> location -> lexpr list -> acsl_extension_kind
type extension_visitor =
  Cil.cilVisitor -> acsl_extension_kind -> acsl_extension_kind Cil.visitAction
type extension_printer =
  Printer_api.extensible_printer_type -> Format.formatter ->
  acsl_extension_kind -> unit

val register_behavior:
  string -> ?preprocessor:extension_preprocessor -> extension_typer ->
  ?visitor:extension_visitor ->
  ?printer:extension_printer -> ?short_printer:extension_printer -> bool ->
  unit

val register_global:
  string -> ?preprocessor:extension_preprocessor -> extension_typer ->
  ?visitor:extension_visitor ->
  ?printer:extension_printer -> ?short_printer:extension_printer -> bool ->
  unit

val register_code_annot:
  string -> ?preprocessor:extension_preprocessor -> extension_typer ->
  ?visitor:extension_visitor ->
  ?printer:extension_printer -> ?short_printer:extension_printer -> bool ->
  unit

val register_code_annot_next_stmt:
  string -> ?preprocessor:extension_preprocessor -> extension_typer ->
  ?visitor:extension_visitor ->
  ?printer:extension_printer -> ?short_printer:extension_printer -> bool ->
  unit

val register_code_annot_next_loop:
  string -> ?preprocessor:extension_preprocessor -> extension_typer ->
  ?visitor:extension_visitor ->
  ?printer:extension_printer -> ?short_printer:extension_printer -> bool ->
  unit

val register_code_annot_next_both:
  string -> ?preprocessor:extension_preprocessor -> extension_typer ->
  ?visitor:extension_visitor ->
  ?printer:extension_printer -> ?short_printer:extension_printer -> bool ->
  unit
