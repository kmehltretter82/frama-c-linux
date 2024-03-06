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

(** Conversion to Cil *)

val to_cil_exp : exp -> Cil_types.exp
val to_cil_lval : lval -> Cil_types.lval

(** Expressions/Lvalue heights *)

(** Computes the height of an expression, that is the maximum number of nested
    operations in this expression. *)
val height_exp : exp -> int

(** Computes the height of an lvalue. *)
val height_lval : lval -> int

(** Relations *)

(** Inverse a relation, op must be a comparison operator *)
val invert_relation : binop -> binop

(** Convert a relation to Abstract_interp.Comp, op must be a comparison
    operator *)
val conv_relation : binop -> Abstract_interp.Comp.t

(** Specialized visitors *)

(** [iter_lvals f exp] calls [f] from every lvalue contained in [exp] *)
val iter_lvals : (lval -> unit) -> exp -> unit

(** [exp_contains_volatile e] (resp. [lval_contains_volatile lv] is true
    whenever one l-value contained inside the expression [e] (resp. the lvalue
    [lv]) has volatile qualifier. Relational analyses should not learn
    anything on such values. *)
val exp_contains_volatile : exp -> bool
val lval_contains_volatile : lval -> bool

val vars_in_exp : exp -> Cil_datatype.Varinfo.Set.t
val vars_in_lval : lval -> Cil_datatype.Varinfo.Set.t

(** Dependences of expressions and lvalues. *)

val zone_of_exp:
  (lval -> Precise_locs.precise_location) -> exp -> Locations.Zone.t
(** Given a function computing the location of lvalues, computes the memory zone
    on which the value of an expression depends. *)

val zone_of_lval:
  (lval -> Precise_locs.precise_location) -> lval -> Locations.Zone.t
(** Given a function computing the location of lvalues, computes the memory zone
    on which the value of an lvalue depends. *)

val indirect_zone_of_lval:
  (lval -> Precise_locs.precise_location) -> lval -> Locations.Zone.t
(** Given a function computing the location of lvalues, computes the memory zone
    on which the offset and the pointer expression (if any) of an lvalue depend.
*)

val deps_of_exp:
  (lval -> Precise_locs.precise_location) -> exp -> Deps.t
(** Given a function computing the location of lvalues, computes the memory
    dependencies of an expression. *)

val deps_of_lval: (lval -> Precise_locs.precise_location) -> lval -> Deps.t
(** Given a function computing the location of lvalues, computes the memory
    dependencies of an lvalue. *)

(** Constant folding. *)

val const_fold: exp -> exp
val fold_to_integer: exp -> Integer.t option

(** Offsets *)

(** Returns the last offset in the chain. *)
val last_offset: offset -> offset

(** Is an lvalue a bitfield? *)
val is_bitfield: lval -> bool
