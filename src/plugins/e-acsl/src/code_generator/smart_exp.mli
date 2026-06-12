(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(* ********************************************************************** *)
(* Helper functions to build expressions *)
(* ********************************************************************** *)

val new_exp : loc:Fileloc.t -> exp_node -> exp
(** Like {!Cil.new_exp}: creates an expression with a fresh id; but it also
    removes any \ghost attributes from types occurring from the result. Ghost
    attributes should never appear in the generated code, so this function is
    to be preferred over {!Cil.new_exp} in any code generation context. *)

val lval: loc:Fileloc.t -> lval -> exp
(** Construct an lval expression from an lval. *)

val deref: loc:Fileloc.t -> exp -> exp
(** Construct a dereference of an expression. *)

val subscript: loc:Fileloc.t -> exp -> exp -> exp
(** [mk_subscript ~loc array idx] Create an expression to access the [idx]'th
    element of the [array]. *)

val ptr_sizeof: loc:Fileloc.t -> typ -> exp
(** [ptr_sizeof ~loc ptr_typ] takes the pointer typ [ptr_typ] that points
    to a [typ] typ and returns [sizeof(typ)]. *)

val lnot: loc:Fileloc.t -> exp -> exp
(** [lnot ~loc e] creates a logical not on the given expression [e]. *)

val null: loc:Fileloc.t -> exp
(** [null ~loc] creates an expression to represent the NULL pointer. *)

val mem: loc:Fileloc.t -> varinfo -> exp
(** [mem ~loc v] creates a Mem expression with an explicit index of 0 *)
