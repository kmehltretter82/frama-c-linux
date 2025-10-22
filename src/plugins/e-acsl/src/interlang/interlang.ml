(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Analyses_datatype


type binop =
  | Plus | Minus | Mult | Div | Mod
  | Lt | Gt | Le | Ge | Eq | Ne (* arithmetic comparison *)
(* | LAnd | LOr *)

module Varinfo = struct
  type t =
    | Fresh_varinfo of {id : int; ty : typ; name : string; origin : term}
    | Logic_varinfo of Cil_types.varinfo

  let fresh =
    let id = ref (-1) in
    fun ~origin name ty ->
      id := !id + 1;
      Fresh_varinfo {id = !id; ty; name; origin}

  let logic vi = Logic_varinfo vi

  let pretty fmt = function
    | Fresh_varinfo {name} -> Format.pp_print_string fmt name
    | Logic_varinfo v -> Printer.pp_varinfo fmt v
end

type varinfo = Varinfo.t

type exp = {enode : exp_node; origin : term option}

and exp_node =
  | True
  | False
  | Integer of Z.t
  | BinOp of binop_node
  | Lval of lval
  | SizeOf of typ

and binop_node = {ity : Number_ty.t; binop : binop; op1 : exp; op2 : exp}

and lhost =
  | Var of varinfo
  | Mem of exp

and lval = lhost * offset

and offset =
  | NoOffset
  | Field of fieldinfo * offset
  | Index of exp * offset


module Pretty = struct
  open Format

  let pp_varinfo = Varinfo.pretty

  let pp_binop fmt b =
    fprintf fmt "%s"
      (match b with
       | Plus -> "+"
       | Minus -> "-"
       | Mult -> "*"
       | Div -> "/"
       | Mod -> "%"
       | Lt -> "<"
       | Gt -> ">"
       | Le -> "<="
       | Ge -> ">="
       | Eq -> "=="
       | Ne -> "!=")

  let rec pp_lhost fmt = function
    | Var vi -> pp_varinfo fmt vi
    | Mem exp -> fprintf fmt "*@[%a@]" pp_exp exp

  and pp_lval fmt (host,offset) =
    pp_lhost fmt host;
    pp_offset fmt offset

  and pp_offset fmt = function
    | NoOffset -> Printer.pp_offset fmt NoOffset
    | Field (fi, o) ->
      fprintf fmt ".%a%a" Printer.pp_field fi pp_offset o
    | Index (e, o) ->
      fprintf fmt "[%a]%a" pp_exp e pp_offset o

  and pp_exp fmt {enode} = pp_exp_node fmt enode

  and pp_exp_node fmt = function
    | True -> fprintf fmt "true"
    | False -> fprintf fmt "false"
    | Integer n -> Z.pretty fmt n
    | BinOp {binop; op1; op2} ->
      fprintf fmt "@[%a@]@ %a@ @[%a@]" pp_exp op1 pp_binop binop pp_exp op2
    | Lval lval -> pp_lval fmt lval
    | SizeOf ty -> fprintf fmt "SizeOf(@[%a])" Printer.pp_typ ty
end
