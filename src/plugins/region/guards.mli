(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions Generator                                         --- *)
(* -------------------------------------------------------------------------- *)

open Memory
open Cil_types
open Condition

(** Warning: for unspecified sequence,
    you shall visit each sub-stmt individually *)
val guards : map -> (guard -> unit) -> stmt -> unit

val add_annotation :
  ?kf:kernel_function ->
  ?emitter:Emitter.t ->
  ?names:string list ->
  ?invalid:bool ->
  ?hyps:Property.t list ->
  stmt -> guard -> unit

val is_annotated : kernel_function -> bool
val set_annotated : kernel_function -> unit
val annotate : kernel_function -> unit
