(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2018                                               *)
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

(** Fixpoint equation solver for infering intervals of
  recursively defined logic functions *)

(**************************************************************************)
(******************************* Types ************************************)
(**************************************************************************)

type ival_binop = Ival_add | Ival_min | Ival_mul | Ival_div | Ival_union

type ival_exp =
  | Iconst of Ival.t
  | Ivar of string (* function name *) * logic_type list (* args lty *)
    (** Example: to the function signature f(int, long) corresponds
      the expression Ivar("f", [int; long]) *)
  | Ibinop of ival_binop * ival_exp * ival_exp
  | Iunsupported

type t
(** type of systems of equations over [ival_exp] expressions in which the
    variables to be found are the [Ivar] constructs. [Equations.t] can be viewed
    as a fixpoint equation in the sense that the left-hand side of the equation
    MUST be an [Ivar]: solving the system [(S): x1=f1(x1, ..., xn) /\ ... /\
    xn=fn(x1, ..., xn)] is equivalent to solving the fixpoint equation [(E):
    X=F(X)] where X=(x1, ..., xn) and F=(f1, ..., fn). *)

(**************************************************************************)
(*************************** Constructors *********************************)
(**************************************************************************)

val empty: t
val add_equation:
  ival_exp (* left-hand side, MUST be an [Ivar] *) -> ival_exp -> t -> t

(**************************************************************************)
(***************************** Solver *************************************)
(**************************************************************************)

val solve: t -> ival_exp -> Integer.t array -> Ival.t
(** [solve ieqs ivar chain] finds an interval for the variable [ivar]
  that satisfies the fixpoint equation [ieqs]. The solver is parameterized
  by the increasingly sorted array [chain] of positive integers.
  For chain=[n1; n2; ...; nk] where n1 < ... < nk, [solve] will
  consider the following set S of intervals as potential solution:
  S={[-n1, n1], [-n2, n2]... [-nk; nk]}. Then [solve] will iteratively
  affect intervals from S to the different variables of [ieqs],
  starting from the smallest interval [-n1, n1] to the biggest one [-nk,
  nk], until finding the smallest combination that satisfies [ieqs].
  If no combination is found then [solve] returns Z. *)

(**************************************************************************)
(****************************** Utils *************************************)
(**************************************************************************)

val ivars_contains_ivar: ival_exp list -> ival_exp -> bool
(** [contains ivars ivar] checks whether the list of Ivar [ivars] contains the
  Ivar [ivar]. *)
