(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(** Math Operators *)
(* -------------------------------------------------------------------------- *)

open Lang
open Lang.F

val int_of_bool : unop
val bool_of_int : unop

val int_of_real : term -> term
val real_of_int : term -> term

val f_real_of_int : lfun extern
val f_iabs : lfun extern
val f_rabs : lfun extern
val f_sqrt : lfun extern

(* -------------------------------------------------------------------------- *)
