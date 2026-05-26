(******************************************************************************)
(*                                                                            *)
(*  SPDX-License-Identifier LGPL-2.1                                          *)
(*  Copyright (C)                                                             *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)      *)
(*                                                                            *)
(******************************************************************************)

open Cil_types

(**
   Substitution of formals in terms and predicates.
   These operations are intended for replacing formal parameters by actual ones
   in terms or predicates of the function pre-conditions at call site.
   @since Frama-C 33.0-Arsenic
*)

val term: varinfo list -> exp list -> term -> term option
(** [term xs es t] substitutes in term [t] formal parameters [xs] with actual
    parameters [es] and move [Pre] labels to [Here]. Returns [None] if the
    transposition can not be performed. This is the case when an actual
    parameter is missing or when the address of formal is taken. *)

val pred: varinfo list -> exp list -> predicate -> predicate option
(** Same as function {!term} for predicates. *)

val ipred:varinfo list -> exp list -> identified_predicate -> identified_predicate option
(** Same as function {!term} for identified predicates. *)
