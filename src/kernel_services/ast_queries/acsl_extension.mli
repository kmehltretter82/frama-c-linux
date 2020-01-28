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

type extension_info = {
  ext_status: bool ;
  ext_preprocess: extension_preprocessing ;
  ext_typing: extension_typing ;
  ext_visit: extension_visit ;
  ext_printing: extension_printing ;
}
and extension_preprocessing =
  lexpr list -> lexpr list
and extension_typing =
  typing_context -> location -> lexpr list -> acsl_extension_kind
and extension_visit =
  Cil.cilVisitor -> acsl_extension_kind -> acsl_extension_kind Cil.visitAction
and extension_printing =
  Printer_api.extensible_printer_type -> Format.formatter ->
  acsl_extension_kind -> unit

val default: extension_info

val register_behavior: string -> extension_info -> unit
val register_global: string -> extension_info -> unit
val register_code_annot: string -> extension_info -> unit
val register_code_annot_next_stmt: string -> extension_info -> unit
val register_code_annot_next_loop: string -> extension_info -> unit
val register_code_annot_next_both: string -> extension_info -> unit