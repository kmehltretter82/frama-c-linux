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

[@@@ api_start]

(** Eva Syntax Tree. *)

type origin =
  | Lval of Cil_types.lval
  | Exp of Cil_types.exp
  | Term of Cil_types.identified_term
  | Built (* Not present in the original source code *)

type 'a tag = private {
  node: 'a;
  typ: Cil_types.typ;
  origin: origin;
}

type typ = Cil_types.typ
type varinfo = Cil_types.varinfo

type exp = exp_node tag

and exp_node =
  | Const      of constant
  | Lval       of lval
  | UnOp       of unop * exp * typ
  | BinOp      of binop * exp * exp * typ
  | CastE      of typ * exp
  | AddrOf     of lval
  | StartOf    of lval

(** Literal constants *)
and constant =
  | CTopInt of typ (* an unknown integer; currently introduced when sizeof/alignof cannot be evaluated as a constant *)
  | CInt64 of Integer.t * ikind * string option
  | CString of Base.t (* the base must be [Base.String _] *)
  | CChr of char
  | CReal of float * fkind * string option
  | CEnum of Cil_types.enumitem * exp (* the translated expression that this enumitem refers to *)

and lval_node = lhost * offset

and lval = lval_node tag

and lhost =
  | Var of varinfo
  | Mem of exp

and offset =
  | NoOffset
  | Field of Cil_types.fieldinfo * offset
  | Index of exp * offset

and ikind = Cil_types.ikind
and fkind = Cil_types.fkind

and unop = Neg | BNot | LNot

and binop =
  | PlusA
  | PlusPI
  | MinusA
  | MinusPI
  | MinusPP
  | Mult
  | Div
  | Mod
  | Shiftlt
  | Shiftrt
  | Lt
  | Gt
  | Le
  | Ge
  | Eq
  | Ne
  | BAnd
  | BXor
  | BOr
  | LAnd
  | LOr

type init =
  | SingleInit of (exp * Cil_types.location)
  | CompoundInit of typ * (offset * init) list


(* Typing *)

val type_of : 'a tag -> typ
val type_of_exp_node : exp_node -> typ
val type_of_lval_node : lval_node -> typ
val type_of_lhost : lhost -> typ


(* Pretty printing *)

val pp_lval : Format.formatter -> lval -> unit
val pp_offset : Format.formatter -> offset -> unit
val pp_exp : Format.formatter -> exp -> unit
val pp_constant : Format.formatter -> constant -> unit
val pp_unop : Format.formatter -> unop -> unit
val pp_binop : Format.formatter -> binop -> unit


(* Datatypes *)

module Lhost : Datatype.S_with_collections with type t = lhost
module Offset : Datatype.S_with_collections with type t = offset
module Lval : Datatype.S_with_collections with type t = lval
module Exp : Datatype.S_with_collections with type t = exp
module Constant : Datatype.S_with_collections with type t = constant


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


(** Conversion to Cil *)

val to_cil_exp : exp -> Cil_types.exp
val to_cil_lval : lval -> Cil_types.lval


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

  val int: ?kind:Cil_types.ikind -> int -> exp
  val float: kind:Cil_types.fkind -> float -> exp
  val integer: ?kind:Cil_types.ikind -> Integer.t -> exp
  val bool: bool -> exp (* convert booleans to an expression 0 or 1 *)

  val cast: typ -> exp -> exp (* (typ)x *)
  val binop: binop -> exp -> exp -> exp (* x op y *)
  val add: exp -> exp -> exp (* x + y *)
  val eq: exp -> exp -> exp (* x == y *)
  val ne: exp -> exp -> exp (* x != y *)

  val index: lval -> exp -> lval (* x[y] *)
  val field: lval -> Cil_types.fieldinfo -> lval (* x.field *)
  val addr: lval -> exp (* &x *)
  val mem: exp -> lval (* *x *)

  val var: Cil_types.varinfo -> lval
  val var_exp: Cil_types.varinfo -> exp
  val lval: lval -> exp
end


(** Queries *)

val is_mutable : lval -> bool
val is_initialized : lval -> bool


(** Expressions/Lvalue heights *)

(** Computes the height of an expression, that is the maximum number of nested
    operations in this expression. *)
val height_exp : exp -> int

(** Computes the height of an lvalue. *)
val height_lval : lval -> int


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


(** Constant conversion and folding. *)

val to_integer : exp -> Integer.t option
val to_float : exp -> float option
val is_zero : exp -> bool
val is_zero_ptr : exp -> bool
val const_fold: exp -> exp
val fold_to_integer: exp -> Integer.t option


(** Offsets *)

(** Returns the last offset in the chain. *)
val last_offset: offset -> offset

(** Is an lvalue a bitfield? *)
val is_bitfield: lval -> bool


(** Rewriting visitor *)

module Rewrite :
sig
  type visitor = {
    exp : exp -> exp;
    lval : lval -> lval;
    varinfo : varinfo -> varinfo;
    offset : offset -> offset;
  }

  type rewriter = {
    rewrite_exp : visitor:visitor -> exp -> exp;
    rewrite_lval : visitor:visitor -> lval -> lval;
    rewrite_varinfo : visitor:visitor -> varinfo -> varinfo;
    rewrite_offset : visitor:visitor -> offset -> offset;
  }

  val default : rewriter
  val visit_exp : rewriter -> exp -> exp
  val visit_lval : rewriter -> lval -> lval
end


(** Folding visitor *)

module Fold :
sig
  type 'a visitor = {
    neutral : 'a;
    combine : 'a -> 'a -> 'a;
    exp : exp -> 'a;
    lval : lval -> 'a;
    varinfo : varinfo -> 'a;
    offset : offset -> 'a;
  }

  type 'a folder = {
    fold_exp : visitor:'a visitor -> exp -> 'a;
    fold_lval : visitor:'a visitor -> lval -> 'a;
    fold_varinfo : visitor:'a visitor -> varinfo -> 'a;
    fold_offset : visitor:'a visitor -> offset -> 'a;
  }

  val default : 'a folder
  val visit_exp : neutral:'a -> combine:('a -> 'a -> 'a) ->
    'a folder -> exp -> 'a
  val visit_lval : neutral:'a -> combine:('a -> 'a -> 'a) ->
    'a folder -> lval -> 'a
end

[@@@ api_end]
