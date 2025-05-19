(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

open Memory

val add_behavior : kf:kernel_function -> ki:kinstr ->
  ?formal:domain Cil_datatype.Varinfo.Map.t -> ?result:node ->
  map -> funbehavior -> unit
val add_code_annot : kf:kernel_function -> stmt:stmt ->
  ?formal:domain Cil_datatype.Varinfo.Map.t -> ?result:node ->
  map -> code_annotation -> unit
val add_acsl_extension : kf:kernel_function -> stmt:stmt ->
  ?formal:domain Cil_datatype.Varinfo.Map.t -> ?result:node ->
  ca:code_annotation -> map -> acsl_extension -> unit
