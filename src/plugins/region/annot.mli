(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

open Memory

val add_behavior :
  kf:kernel_function -> ki:kinstr ->
  ?formal:domain Cil_datatype.Varinfo.Map.t -> result:node option ->
  iscalled:bool -> map -> funbehavior -> unit

val add_code_annot :
  kf:kernel_function -> stmt:stmt ->
  ?formal:domain Cil_datatype.Varinfo.Map.t -> result:node option ->
  iscalled:bool -> map -> code_annotation -> unit
