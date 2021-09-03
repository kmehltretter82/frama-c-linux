(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(** Generate C implementations of E-ACSL predicates and terms. *)

val predicate_to_exp:
  adata:Assert.t ->
  ?name:string ->
  kernel_function ->
  ?rte:bool ->
  Env.t ->
  predicate ->
  exp * Assert.t * Env.t
(** Convert an ACSL predicate into a corresponding C expression. *)

val generalized_untyped_predicate_to_exp:
  adata:Assert.t ->
  ?name:string ->
  kernel_function ->
  ?rte:bool ->
  ?must_clear_typing:bool ->
  Env.t ->
  predicate ->
  exp * Assert.t * Env.t
(** Convert an untyped ACSL predicate into a corresponding C expression. *)

val translate_predicate:
  ?pred_to_print:predicate ->
  kernel_function ->
  Env.t ->
  toplevel_predicate ->
  Env.t
(** Translate the given predicate to a runtime check in the given environment.
    If [pred_to_print] is set, then the runtime check will use this predicate as
    message. *)

val term_to_exp:
  adata:Assert.t ->
  kernel_function ->
  Env.t ->
  term ->
  exp * Assert.t * Env.t
(** Convert an ACSL term into a corresponding C expression. *)

val translate_rte_annots:
  (Format.formatter -> 'a -> unit) ->
  'a ->
  kernel_function ->
  Env.t ->
  code_annotation list ->
  Env.t
(** Translate the given RTE annotations into runtime checks in the given
    environment. *)

val gmp_to_sizet:
  adata:Assert.t ->
  loc:location ->
  name:string ->
  ?check_lower_bound:bool ->
  ?pp:term ->
  kernel_function ->
  Env.t ->
  term ->
  exp * Assert.t * Env.t
(** Translate the given GMP integer to an expression of type [size_t]. RTE
    checks are generated to ensure that the GMP value holds in this type.
    The parameter [name] is used to generate relevant predicate names.
    If [check_lower_bound] is set to [false], then the GMP value is assumed to
    be positive.
    If [pp] is provided, this term is used in the messages of the RTE checks. *)

exception No_simple_term_translation of term
(** Exceptin raised if [untyped_term_to_exp] would generate new statements in
    the environment *)

exception No_simple_predicate_translation of predicate
(** Exceptin raised if [untyped_predicate_to_exp] would generate new statements
    in the environment *)

val untyped_term_to_exp: typ option -> term -> exp
(** Convert an untyped ACSL term into a corresponding C expression. *)

val untyped_predicate_to_exp: predicate -> exp
(** Convert an untyped ACSL predicate into a corresponding C expression. This
    expression is valid only in certain contexts and shouldn't be used. *)

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
