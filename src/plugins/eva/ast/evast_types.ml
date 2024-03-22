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

open Cil_datatype

(** Eva AST. *)

type origin =
  | Lval of Cil_types.lval
  | Exp of Cil_types.exp
  | Term of Cil_types.identified_term
  | Built (* Not present in the original source code *)

type 'a tag = {
  node: 'a;
  typ: Cil_types.typ;
  origin: origin;
}

let equal_tag equal_node t1 t2 = equal_node t1.node t2.node
let compare_tag compare_node t1 t2 = compare_node t1.node t2.node

type typ = Typ.t [@@deriving eq,ord]
type varinfo = Varinfo.t [@@deriving eq,ord]

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
  | CEnum of Enumitem.t * exp (* the translated expression that this enumitem refers to *)

and lval_node = lhost * offset

and lval = lval_node tag

and lhost =
  | Var of varinfo
  | Mem of exp

and offset =
  | NoOffset
  | Field of Fieldinfo.t * offset
  | Index of exp * offset

and ikind = Cil_types.ikind [@equal (=)] [@compare Stdlib.compare]
and fkind = Cil_types.fkind [@equal (=)] [@compare Stdlib.compare]
[@@deriving eq,ord]


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
