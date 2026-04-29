(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(** Name of "\valid_region" predicate *)
val lvalid_region : string

val is_valid_region : logic_info -> bool

val pvalid_region :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

(* -------------------------------------------------------------------------- *)
(** {2 Logic Helpers} *)
(* -------------------------------------------------------------------------- *)

type addr = LV of lval | ADDR of exp | RANGE of term * typ * term * term
type access = Read | Write | Region | Initialized

type guard =
  | True | False
  | Named of string * guard
  | Or of guard * guard
  | And of guard * guard
  | Imply of guard * guard
  | Bounds of exp * Z.t
  | Null of bool * addr
  | Valid of access * Memory.node * addr
  | Separated of addr * addr

val g_or : guard -> guard -> guard
val g_and : guard -> guard -> guard
val g_imply : guard -> guard -> guard

val pp_addr  : Format.formatter -> addr  -> unit
val pp_guard : Format.formatter -> guard -> unit

val pointed : addr -> typ

val of_addr  : ?loc:location -> addr -> term
val of_guard : ?loc:location -> ?names:string list -> guard -> predicate

(* -------------------------------------------------------------------------- *)
