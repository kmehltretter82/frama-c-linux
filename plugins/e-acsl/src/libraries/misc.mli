(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Utilities for E-ACSL. *)

open Cil_types

(* ************************************************************************** *)
(** {2 Handling \result} *)
(* ************************************************************************** *)

val result_lhost: kernel_function -> lhost
(** @return the lhost corresponding to \result in the given function *)

val result_vi: kernel_function -> varinfo
(** @return the varinfo corresponding to \result in the given function *)

(* ************************************************************************** *)
(** {2 Other stuff} *)
(* ************************************************************************** *)

val is_fc_or_compiler_builtin: varinfo -> bool

val is_fc_stdlib_generated: varinfo -> bool
(** @return true if the [varinfo] is a generated stdlib function. (For instance
    generated function by the Variadic module. *)

val cty: logic_type -> typ
(** Assume that the logic type is indeed a C type. Just return it. *)

val ptr_base: loc:Fileloc.t -> exp -> exp
(** Takes an expression [e] and return [base] where [base] is the address [p]
    if [e] is of the form [p + i] and [e] otherwise. *)

val ptr_base_and_base_addr: loc:Fileloc.t -> exp -> exp * exp
(* Takes an expression [e] and return a tuple [(base, base_addr)] where [base]
   is the address [p] if [e] is of the form [p + i] and [e] otherwise, and
   [base_addr] is the address [&p] if [e] is of the form [p + i] and 0
   otherwise. *)

val is_signed_int: logic_type -> bool
(** Checks whether the given logic type is a signed [int] or an [integer]. *)

val is_set_of_ptr_or_array: logic_type -> bool
(** Checks whether the given logic type is a set of pointers. *)

val is_bitfield_pointers: logic_type -> bool
(** @return true iff the given logic type is a bitfield pointer or a
    set of bitfield pointers. *)

val name_of_unop: unop -> string
(** @return the name of the given unop as a string. *)

val name_of_binop: binop -> string
(** @return the name of the given binop as a string. *)

val make_binop: loc:Fileloc.t -> binop -> exp -> exp -> exp
(** Calls {!Cil.mkBinOp_exn} with [constfold] set to [true].
    @since 33.0-Arsenic *)

val finite_min_and_max: Ival.t -> Z.t * Z.t
(** [finite_min_and_max i] takes the finite ival [i] and returns its bounds. *)

val extract_uncoerced_lval: exp -> exp option
(** Unroll the [CastE] part of the expression until an [Lval] is found, and
    return it.

    If at some point the expression is neither a [CastE] nor an [Lval], then
    return [None]. *)

val labels_are_all_here : logic_label list -> bool
(** @return [true] if all labels are the builtin label Here (or list is empty). *)

val unghost_type : typ -> typ
(** remove all occurrences (also deep ones) of the "ghost" attribute. *)

val get_loc_from_pot : Analyses_types.pred_or_term -> Fileloc.t

val get_term_from_pot : Analyses_types.pred_or_term -> term option
