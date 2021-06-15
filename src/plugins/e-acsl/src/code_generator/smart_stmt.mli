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

(* ********************************************************************** *)
(* Helper functions to build statements *)
(* ********************************************************************** *)

val stmt: stmtkind -> stmt
(** Create a statement from a statement kind. *)

val block: stmt -> block -> stmt
(** Create a block statement from a block to replace a given statement.
    Requires that (1) the block is not empty, or (2) the statement is a skip. *)

val block_stmt: block -> stmt
(** Create a block statement from a block *)

val block_from_stmts: stmt list -> stmt
(** Create a block statement from a statement list. *)

val assigns: loc:location -> result:lval -> exp -> stmt
(** [assigns ~loc ~result value] create a statement to assign the [value]
    expression to the [result] lval. *)

val if_stmt:
  loc:location -> cond:exp -> ?else_blk:block -> block -> stmt
(** [if ~loc ~cond ~then_blk ~else_blk] create an if statement with [cond]
    as condition and [then_blk] and [else_blk] as respectively "then" block and
    "else" block. *)

val break: loc:location -> stmt
(** Create a break statement *)

(* ********************************************************************** *)
(* E-ACSL specific code: build calls to its RTL API *)
(* ********************************************************************** *)

val call: loc:location -> ?result:lval -> string -> exp list -> stmt
(** Construct a call to a function with the given name.
    @raise Not_found if the given string does not represent a function in the
    AST, for instance if the function does not exist. *)

val rtl_call:
  loc:location -> ?result:lval -> ?prefix:string -> string -> exp list -> stmt
(** Construct a call to a library function with the given name.

    [prefix] defaults to the E-ACSL RTL API prefix and can be explicitely
    provided to call functions without this prefix.

    @raise Rtl.Symbols.Unregistered if the given string does not represent
    such a function or if library functions were never registered (only possible
    when using E-ACSL through its API). *)

val store_stmt: ?str_size:exp -> varinfo -> stmt
(** Construct a call to [__e_acsl_store_block] that observes the allocation of
    the given varinfo. See [share/e-acsl/e_acsl.h] for details about this
    function. *)

val duplicate_store_stmt: ?str_size:exp -> varinfo -> stmt
(** Same as [store_stmt] for [__e_acsl_duplicate_store_block] that first
    checks for a previous allocation of the given varinfo. *)

val delete_stmt: ?is_addr:bool -> varinfo -> stmt
(** Same as [store_stmt] for [__e_acsl_delete_block] that observes the
    de-allocation of the given varinfo.
    If [is_addr] is false (default), take the address of varinfo. *)

val full_init_stmt: varinfo -> stmt
(** Same as [store_stmt] for [__e_acsl_full_init] that observes the
    initialization of the given varinfo. The varinfo is the address to fully
    initialize, no [addrOf] is taken. *)

val initialize: loc:location -> lval -> stmt
(** Same as [store_stmt] for [__e_acsl_initialize] that observes the
    initialization of the given left-value. *)

val mark_readonly: varinfo -> stmt
(** Same as [store_stmt] for [__e_acsl_markreadonly] that observes the
    read-onlyness of the given varinfo. *)

type annotation_kind =
  | Assertion
  | Precondition
  | Postcondition
  | Invariant
  | Variant
  | RTE

val runtime_check:
  pred_kind:predicate_kind -> annotation_kind -> kernel_function -> exp ->
  predicate -> stmt
(** [runtime_check ~pred_kind kind kf e p] generates a runtime check for
    predicate [p] by building a call to [__e_acsl_assert]. [e] (or [!e] if
    [reverse] is set to [true]) is the C translation of [p], [kf] is the current
    kernel_function, [kind] is the annotation kind of [p] and [pred_kind]
    indicates if the assert should be blocking or not. *)

val runtime_check_with_msg:
  loc:location -> string -> pred_kind:predicate_kind -> annotation_kind ->
  kernel_function -> exp -> stmt
(** [runtime_check_with_msg ~loc msg ~pred_kind kind kf e] generates a runtime
    check for [e] (or [!e] if [reverse] is [true]) by building a call to
    [__e_acsl_assert]. [msg] is the message printed if the runtime check fails.
    [loc] is the location printed in the message if the runtime check fails.
    [kf] is the current kernel_function, [kind] is the annotation kind of [p]
    and [pred_kind] indicates if the assert should be blocking or not. *)

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
