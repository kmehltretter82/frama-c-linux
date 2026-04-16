(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Memory

val lval : map -> lval -> node
val exp : map -> exp -> node option

val term : Logic.env -> term -> domain
val term_lval : Logic.env -> term_lval -> domain
