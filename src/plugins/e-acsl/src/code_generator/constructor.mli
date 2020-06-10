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

(** Smart constructors for building C code. *)

open Cil_types
open Cil_datatype

(* ********************************************************************** *)
(* Expressions *)
(* ********************************************************************** *)

val extract_uncoerced_lval: exp -> exp option
(** Unroll the [CastE] part of the expression until an [Lval] is found, and
    return it.

    If at some point the expression is neither a [CastE] nor an [Lval], then
    return [None]. *)

val mk_lval: loc:location -> lval -> exp
(** Construct an lval expression from an lval. *)

val mk_deref: loc:Location.t -> exp -> exp
(** Construct a dereference of an expression. *)

val mk_subscript: loc:location -> exp -> exp -> exp
(** [mk_subscript ~loc array idx] Create an expression to access the [idx]'th
    element of the [array]. *)

(* ********************************************************************** *)
(* Statements *)
(* ********************************************************************** *)

val mk_stmt: stmtkind -> stmt
(** Create a statement from a statement kind. *)

val mk_block: stmt -> block -> stmt
(** Create a block statement from a block to replace a given statement.
    Requires that (1) the block is not empty, or (2) the statement is a skip. *)

val mk_block_stmt: block -> stmt
(** Create a block statement from a block *)

val mk_assigns: loc:location -> result:lval -> exp -> stmt
(** [mk_assigns ~loc ~result value] create a statement to assign the [value]
    expression to the [result] lval. *)

val mk_if:
  loc:location -> cond:exp -> ?else_blk:block -> block -> stmt
(** [mk_if ~loc ~cond ~then_blk ~else_blk] create an if statement with [cond]
    as condition and [then_blk] and [else_blk] as respectively "then" block and
    "else" block. *)

val mk_break: loc:location -> stmt
(** Create a break statement *)

(* ********************************************************************** *)
(* E-ACSL specific code: build calls to its RTL API *)
(* ********************************************************************** *)

val mk_lib_call: loc:Location.t -> ?result:lval -> string -> exp list -> stmt
(** Construct a call to a library function with the given name.
    @raise Unregistered_library_function if the given string does not represent
    such a function or if library functions were never registered (only possible
    when using E-ACSL through its API). *)

val mk_rtl_call: loc:Location.t -> ?result:lval -> string -> exp list -> stmt
(** Special version of [mk_lib_call] for E-ACSL's RTL functions. *)

val mk_store_stmt: ?str_size:exp -> varinfo -> stmt
(** Construct a call to [__e_acsl_store_block] that observes the allocation of
    the given varinfo. See [share/e-acsl/e_acsl.h] for details about this
    function. *)

val mk_duplicate_store_stmt: ?str_size:exp -> varinfo -> stmt
(** Same as [mk_store_stmt] for [__e_acsl_duplicate_store_block] that first
    checks for a previous allocation of the given varinfo. *)

val mk_delete_stmt: ?is_addr:bool -> varinfo -> stmt
(** Same as [mk_store_stmt] for [__e_acsl_delete_block] that observes the
    de-allocation of the given varinfo.
    If [is_addr] is false (default), take the address of varinfo. *)

val mk_full_init_stmt: varinfo -> stmt
(** Same as [mk_store_stmt] for [__e_acsl_full_init] that observes the
    initialization of the given varinfo. The varinfo is the address to fully
    initialize, no [addrOf] is taken. *)

val mk_initialize: loc:location -> lval -> stmt
(** Same as [mk_store_stmt] for [__e_acsl_initialize] that observes the
    initialization of the given left-value. *)

val mk_mark_readonly: varinfo -> stmt
(** Same as [mk_store_stmt] for [__e_acsl_markreadonly] that observes the
    read-onlyness of the given varinfo. *)

type annotation_kind =
  | Assertion
  | Precondition
  | Postcondition
  | Invariant
  | RTE

val mk_runtime_check:
  annotation_kind -> kernel_function -> exp -> predicate -> stmt
(** [mk_runtime_check kind kf e p] generates a runtime check for predicate [p]
    by building a call to [__e_acsl_assert]. [e] (or [!e] if [reverse] is set to
    [true]) is the C translation of [p], [kf] is the current kernel_function and
    [kind] is the annotation kind of [p]. *)

val mk_runtime_check_with_msg:
  loc:location -> string -> annotation_kind -> kernel_function -> exp -> stmt
(** [mk_runtime_check_with_msg kind kf e msg] generates a runtime check for [e]
    (or [!e] if [reverse] is [true]) by building a call to [__e_acsl_assert].
    [msg] is the message printed if the runtime check fails. [loc] is the
    location printed in the message if the runtime check fails. [kf] is the
    current kernel_function and [kind] is the annotation kind of [p]. *)

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
