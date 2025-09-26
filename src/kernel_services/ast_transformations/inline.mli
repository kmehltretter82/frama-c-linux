(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

val inline_calls : file -> unit

(** [inline_term ~inline term] inlines in [term] the application of predicates
    and logic functions for which [inline] is true. If provided, [current] is
    the current label of the term; it is [Here] by default. Returns [None]
    if the inlining of a predicate or a logic function fails, in particular
    when they are recursive or have no direct definition. *)
val inline_term:
  inline:(logic_info -> bool) -> ?current:logic_label -> term -> term option

(** Inlines predicates and logic functions in a predicate. See [inline_term]
    for details. *)
val inline_predicate:
  inline:(logic_info -> bool) -> ?current:logic_label ->
  predicate -> predicate option
