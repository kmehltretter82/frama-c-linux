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
   @since Frama-C 33.0-Arsenic
*)

val term:
  formals:varinfo list -> concretes:exp list ->
  term -> term option
(** [transpose_pred_at_callsite ~formals ~concretes t] substitutes in term [t]
    formal parameters with concrete values and move [Pre] labels to [Here].
    Returns [None] if ever the address of a formal is taken. *)

val pred:
  formals:varinfo list -> concretes:exp list ->
  predicate -> predicate option
(** Same as to [transpose_term_at_callsite] for predicates. *)

val ipred:
  formals:varinfo list -> concretes:exp list ->
  identified_predicate -> identified_predicate option
(** Same as to [transpose_term_at_callsite] for identified predicates. *)
