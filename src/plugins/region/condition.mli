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

type addr = L of lval | E of exp | T of term * typ | R of term * typ * term * term
type access = Read | Write | Region | Initialized

(** Tip: named terms are opaque to smart constructors *)

type guard = private
  | True
  | Invalid of guard (* original guard *)
  | Named of string * guard
  | Or of guard * guard
  | And of guard * guard
  | Imply of guard * guard
  | Bounds of exp * Z.t
  | Null of bool * addr
  | Valid of access * addr
  | Separated of addr * addr

val pointed : addr -> typ
val trivial : guard -> bool
val invalid : guard -> bool
val falsy : guard -> guard

val g_true : guard
val g_invalid : guard -> guard
val g_or : guard -> guard -> guard
val g_and : guard -> guard -> guard
val g_imply : guard -> guard -> guard
val g_name : string -> guard -> guard
val g_null : ?eq:bool -> addr -> guard
val g_bounds : exp -> Z.t -> guard
val g_valid : access -> addr -> guard
val g_separated : addr -> addr -> guard

val pp_addr  : Format.formatter -> addr  -> unit
val pp_guard : Format.formatter -> guard -> unit

val of_addr  : ?loc:location -> addr -> term
val of_guard : ?loc:location -> ?names:string list -> guard -> predicate

(* -------------------------------------------------------------------------- *)
