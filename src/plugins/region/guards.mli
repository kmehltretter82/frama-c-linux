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

type addr = LV of lval | ADDR of exp
type guard =
  | Bounds of exp * Z.t
  | Valid_region of node * addr

val pp_addr  : Format.formatter -> addr  -> unit
val pp_guard : Format.formatter -> guard -> unit

val of_addr  : ?loc:location -> addr -> term
val of_guard : ?loc:location -> ?names:string list -> guard -> predicate

val pointed : addr -> typ

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
