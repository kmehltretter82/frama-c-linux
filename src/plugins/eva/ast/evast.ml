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

(** Eva AST. *)

type cil =
  | Exp of Cil_types.exp
  | Term of Cil_types.term

type exp =
  { node: exp_node;
    origin: cil }

and exp_node =
  | Const      of constant
  | Lval       of lval
  | SizeOf     of typ
  | SizeOfE    of exp
  | SizeOfStr  of string
  | AlignOf    of typ
  | AlignOfE   of exp
  | UnOp       of unop * exp * typ
  | BinOp      of binop * exp * exp * typ
  | CastE      of typ * exp
  | AddrOf     of lval
  | StartOf    of lval

(** Literal constants *)
and constant =
  | CInt64 of Integer.t * ikind * string option
  | CStr of string
  | CWStr of int64 list
  | CChr of char
  | CReal of float * fkind * string option
  | CEnum of enumitem

and lval = lhost * offset

and lhost =
  | Var of Cil_types.varinfo
  | Mem of exp

and offset =
  | NoOffset
  | Field of Cil_types.fieldinfo * offset
  | Index of exp * offset

and typ = Cil_types.typ
and ikind = Cil_types.ikind
and fkind = Cil_types.fkind
and enumitem = Cil_types.enumitem

and unop = Neg | BNot | LNot

and binop =
  | PlusA
  | PlusPI
  | IndexPI
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
