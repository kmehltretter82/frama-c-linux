(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

open Eva_ast_types

(* Constructors *)

val mk_exp : exp_node -> exp
val mk_lval : lval_node -> lval


(* Translation from Cil *)

val translate_exp : Cil_types.exp -> exp
val translate_lval : Cil_types.lval -> lval
val translate_offset : Cil_types.offset -> offset
val translate_unop : Cil_types.unop -> unop
val translate_binop : Cil_types.binop -> binop
val translate_init : Cil_types.init -> init


(* Relations *)

(** Inverse a relation, op must be a comparison operator *)
val invert_relation : binop -> binop

(** Convert a relation to Abstract_interp.Comp, op must be a comparison
    operator *)
val conv_relation : binop -> Abstract_interp.Comp.t

(** [normalize_condition e positive] returns the expression corresponding to
    [e != 0] when [positive] is true, and [e == 0] otherwise. The
    resulting expression will always have a comparison operation at its
    root. *)
val normalize_condition: exp -> bool -> exp


(* Offsets *)

val add_offset: lval -> offset -> lval


(* Smart constructors *)

module Build :
sig
  val zero: exp
  val one: exp

  val int: ikind:Cil_types.ikind -> int -> exp
  val float: fkind:Cil_types.fkind -> float -> exp
  val integer: ikind:Cil_types.ikind -> Integer.t -> exp
  val bool: bool -> exp (* convert booleans to an expression 0 or 1 *)

  val cast: typ -> exp -> exp (* (typ)x *)
  val add: exp -> exp -> exp (* x + y *)
  val div: exp -> exp -> exp (* x / y *)
  val eq: exp -> exp -> exp (* x == y *)
  val ne: exp -> exp -> exp (* x != y *)

  val index: lval -> exp -> lval (* x[y] *)
  val field: lval -> Cil_types.fieldinfo -> lval (* x.field *)
  val mem: exp -> lval (* *x *)

  val var: Cil_types.varinfo -> lval
  val var_exp: Cil_types.varinfo -> exp
  val var_addr: Cil_types.varinfo -> exp (* &vi *)

  val lval: lval -> exp
end
