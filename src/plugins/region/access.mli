(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

type acs =
  | Exp of stmt * exp
  | Lval of stmt * lval
  | Init of stmt * varinfo
  | Term of Property.t * term_lval

val compare : acs -> acs -> int
val pretty : Format.formatter -> acs -> unit

val typeof : acs -> typ

module Set : Set.S with type elt = acs
