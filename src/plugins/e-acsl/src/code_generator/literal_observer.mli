(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Observation of literal strings in C expressions. *)

open Cil_types

val subst_all_literals_in_exp: Env.t -> kernel_function -> exp -> exp * Env.t
(** Replace any sub-expression of the given exp that is a literal string by an
    observed variable. *)
