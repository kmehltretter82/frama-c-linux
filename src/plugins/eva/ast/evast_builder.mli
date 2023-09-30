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

open Evast

val translate_exp: Cil_types.exp -> exp
val translate_lval: Cil_types.lval -> lval
val translate_unop: Cil_types.unop -> unop
val translate_binop: Cil_types.binop -> binop

val mk: exp_node -> exp (* Does not assign origin. Should not be used. *)
val mk_lval: lval_node -> lval

val zero: exp
val one: exp

val int: ?kind:Cil_types.ikind -> int -> exp
val float: kind:Cil_types.fkind -> float -> exp
val integer: ?kind:Cil_types.ikind -> Integer.t -> exp
val bool: bool -> exp (* convert booleans to an expression 0 or 1 *)

val binop: binop -> exp -> exp -> exp
val add: exp -> exp -> exp

val var: Cil_types.varinfo -> lval
val var_exp: Cil_types.varinfo -> exp
val lval: lval -> exp
