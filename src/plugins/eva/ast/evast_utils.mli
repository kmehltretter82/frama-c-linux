(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

(** *)

open Evast

val type_of_exp : exp -> typ
val type_of_lval : lval -> typ

(** These functions are given here as a temporary stub and should not be used *)
val origin_exp : exp -> Cil_types.exp
val origin_lval : lval -> Cil_types.lval
val origin_offset : offset -> Cil_types.offset

(** [rewrite f exp] rewrites [exp] by calling [f ~descent node] on root exp. [f]
    can call [descent e] to rewrite recursively subexpressions of [e]. *)
val rewrite : (descend:(exp -> exp) -> exp -> exp) -> exp -> exp

(** [cost_fold exp] will only replace expressions which originates from Cil
    by calling Cil.constFold on them *)
val const_fold : exp -> exp

(** Computes the height of an expression, that is the maximum number of nested
    operations in this expression. *)
val height_exp : exp -> int

(** Computes the height of an lvalue. *)
val height_lval : lval -> int

(** Inverse a relation, op must be a comparison operator *)
val invert_relation : binop -> binop

(** [exp_contains_volatile e] (resp. [lval_contains_volatile lv] is true
    whenever one l-value contained inside the expression [e] (resp. the lvalue
    [lv]) has volatile qualifier. Relational analyses should not learn
    anything on such values. *)
val exp_contains_volatile : exp -> bool
val lval_contains_volatile : lval -> bool
