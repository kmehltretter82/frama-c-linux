(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(** Generate C implementations of E-ACSL terms. *)

val to_exp:
  adata:Assert.t ->
  ?inplace:bool ->
  kernel_function ->
  Env.t ->
  term ->
  exp * Assert.t * Env.t
(** [to_exp ~adata ?inplace kf env t] converts an ACSL term into a
    corresponding C expression.
    - [adata]: assertion context.
    - [inplace]: if the root term has a label, indicates if it should be
      immediately translated or if [Translate_ats] should be used to retrieve
      the translation.
    - [kf]: The enclosing function.
    - [env]: The current environment.
    - [t]: The term to translate. *)

val to_exp_il : ?inplace:bool -> term -> Interlang.exp Interlang_gen.m
(** a version of [to_exp] that translates ACSL terms to the intermediate
    language instead to Cil. *)

val denominator_zero_guard :
  loc:location ->
  ctx:Analyses_types.number_ty ->
  adata:Assert.t ->
  kf:kernel_function ->
  env:Env.t ->
  name:string ->
  ?root:term ->
  term ->
  exp * stmt * Assert.t * Env.t
(** [denominator_zero_guard ~loc ~ctx ~adata ~kf ~env ~name ?root denom]
    converts the ACSL term [denom], representing the denominator of a division
    or modulo, into a corresponding expression using [to_exp] and a guard
    statement checking that [denom != 0].
    - [loc]: location used for the assertion.
    - [ctx]: context used to create the [zero] term of the guard statement.
    - [adata]: assertion context.
    - [kf]: enclosing function.
    - [env]: current environment.
    - [name]: used for temporary variable names.
    - [root]: root term containing the original division or modulo.
    - [denom]: the term to translate. *)

exception No_simple_translation of term
(** Exceptin raised if [untyped_to_exp] would generate new statements in
    the environment *)

val untyped_to_exp: typ option -> term -> exp
(** Convert an untyped ACSL term into a corresponding C expression. *)

(**************************************************************************)
(********************** Forward references ********************************)
(**************************************************************************)

val translate_rte_exp_ref:
  (?filter:(code_annotation -> bool) ->
   kernel_function ->
   Env.t ->
   exp ->
   Env.t) ref
