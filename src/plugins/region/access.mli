(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

type clause =
  | Body of logic_info
  | Prop of Property.t
  | Call of stmt * kernel_function * Property.t

type acs =
  | Exp of stmt * exp
  | Lval of stmt * lval
  | Init of stmt * varinfo
  | Term of clause * term_lval

val typeof : acs -> typ

val compare : acs -> acs -> int
val compare_clause : clause -> clause -> int

val pretty : Format.formatter -> acs -> unit
val pp_label : Format.formatter -> stmt -> unit
val pp_clause : Format.formatter -> clause -> unit
val pp_source : Format.formatter -> acs -> unit

val marker : acs -> Printer_tag.localizable
val location : clause -> location

module Set : Set.S with type elt = acs
