(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

module Precedence =
struct
  let lval_level lv = match lv.node with
    | Mem _, _
    | Var _, (Field _|Index _) -> 20
    | Var _, NoOffset -> 0

  let exp_level e = match e.node with
    | BinOp (LAnd, _,_,_) -> 83
    | BinOp (LOr, _,_,_) -> 85
    | BinOp ((BOr|BXor|BAnd),_,_,_) -> 75
    | BinOp ((Eq|Ne|Gt|Lt|Ge|Le),_,_,_) -> 70
    | BinOp ((MinusA|MinusPP|MinusPI|PlusA|PlusPI|Shiftlt|Shiftrt),_,_,_) -> 60
    | BinOp ((Div|Mod|Mult),_,_,_) -> 40
    | CastE (_,_) | AddrOf(_) | StartOf(_) | UnOp((Neg|BNot|LNot),_,_) -> 30
    | Lval (lval) -> lval_level lval
    | SizeOf _ | SizeOfE _ | SizeOfStr _ -> 20
    | AlignOf _ | AlignOfE _ -> 20
    | Const _ -> 0
end

let pp_string fmt s =
  Format.fprintf fmt "\"%s\"" (Escape.escape_string s)

let rec pp_lval fmt lval =
  let precedence = Precedence.lval_level lval in
  match lval.node with
  | Var vi, o ->
    Format.fprintf fmt "%s%a" vi.vname pp_offset o
  | Mem e, Field(fi, o) ->
    Format.fprintf fmt "%a->%s%a" (pp_exp' ~precedence) e fi.fname pp_offset o
  | Mem e, NoOffset ->
    Format.fprintf fmt "*%a" (pp_exp' ~precedence) e
  | Mem e, o ->
    Format.fprintf fmt "(*%a)%a" (pp_exp' ~precedence) e pp_offset o

and pp_lval' ~precedence fmt lval =
  if Precedence.lval_level lval >= precedence then
    Format.fprintf fmt "(%a)" pp_lval lval
  else
    pp_lval fmt lval

and pp_offset fmt = function
  | NoOffset -> ()
  | Field (fi, o) ->
    Format.fprintf fmt ".%s%a" fi.Cil_types.fname pp_offset o
  | Index (e, o) ->
    Format.fprintf fmt "[%a]%a" pp_exp e pp_offset o

and pp_exp fmt exp =
  let precedence = Precedence.exp_level exp in
  match exp.node with
  | Const (c) ->
    pp_constant fmt c
  | Lval (lv) ->
    pp_lval fmt lv
  | UnOp (op,e1,_) ->
    Format.fprintf fmt "%a %a" pp_unop op (pp_exp' ~precedence) e1
  | BinOp (op,e1,e2,_) ->
    Format.fprintf fmt "@[%a %a %a@]"
      (pp_exp' ~precedence) e1
      pp_binop op
      (pp_exp' ~precedence) e2
  | CastE(t,e) ->
    Format.fprintf fmt "(%a)%a" Printer.pp_typ t (pp_exp' ~precedence) e
  | SizeOf (t,_) ->
    Format.fprintf fmt "sizeof(%a)" Printer.pp_typ t
  | SizeOfE (e,_) ->
    Format.fprintf fmt "sizeof(%a)" pp_exp e
  | SizeOfStr (s,_) ->
    Format.fprintf fmt "sizeof(%a)" pp_string s
  | AlignOf (t,_) ->
    Format.fprintf fmt "__alignof__(%a)" Printer.pp_typ t
  | AlignOfE (e,_) ->
    Format.fprintf fmt "__alignof__(%a)" pp_exp e
  | AddrOf lv ->
    Format.fprintf fmt "& %a" (pp_lval' ~precedence) lv
  | StartOf(lv) ->
    Format.fprintf fmt "&(%a[0])" (pp_lval' ~precedence) lv

and pp_exp' ~precedence fmt exp =
  if Precedence.exp_level exp >= precedence then
    Format.fprintf fmt "(%a)" pp_exp exp
  else
    pp_exp fmt exp

and pp_unop fmt u =
  let s = match u with
    | Neg -> "-"
    | BNot -> "~"
    | LNot -> "!"
  in
  Format.fprintf fmt "%s" s

and pp_binop fmt b =
  let s = match b with
    | PlusA | PlusPI -> "+"
    | MinusA | MinusPP | MinusPI -> "-"
    | Mult -> "*"
    | Div -> "/"
    | Mod -> "%"
    | Shiftlt -> "<<"
    | Shiftrt -> ">>"
    | Lt -> "<"
    | Gt -> ">"
    | Le -> "<="
    | Ge -> ">="
    | Eq -> "=="
    | Ne -> "!="
    | BAnd -> "&"
    | BXor -> "^"
    | BOr -> "|"
    | LAnd -> "&&"
    | LOr -> "||"
  in
  Format.fprintf fmt "%s" s

and pp_constant fmt = function
  | CInt64 (_, _, Some s) ->
    Format.fprintf fmt "%s" s
  | CInt64 (i, _, _) ->
    Integer.pretty fmt i
  | CString base ->
    Base.pretty fmt base
  | CChr c ->
    Format.fprintf fmt "'%s'" (Escape.escape_char c)
  | CReal (_, _, Some s) ->
    Format.fprintf fmt "%s" s
  | CReal (f, _, None) ->
    Floating_point.pretty fmt f
  | CEnum { einame } ->
    Format.fprintf fmt "%s" einame
