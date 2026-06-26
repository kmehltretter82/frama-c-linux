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
  | Plus | Minus | Mult | Div | Mod (* arithmetic operators *)
  | Lt | Gt | Le | Ge | Eq | Ne (* arithmetic comparison *)
  | And | Or (* logical operators *)

type unop =
  | Neg   (* arithmetic operator *)
  | Not  (* Logical operator *)

type exp =
  {
    enode : exp_node;
    rtes : rte list;
    origin : Pred_or_term.t
  }

and exp_node =
  | Integer of {ity : Number_ty.t; n : Z.t}
  | UnOp of unop_node
  | BinOp of binop_node
  | If of {ity : Number_ty.t; op1 : exp; op2 : exp; op3 : exp}
  | Lval of lval
  | SizeOf of typ
  | Coerce of {coerce_to : typ; coerced : exp}

and unop_node = {ity : Number_ty.t; unop : unop; op : exp}

and binop_node = {ity : Number_ty.t; binop : binop; op1 : exp; op2 : exp}

and lhost =
  | Var of varinfo
  | Mem of exp

and lval = lhost * offset

and offset =
  | NoOffset
  | Field of fieldinfo * offset
  | Index of exp * offset

and rte = {rnode : exp_node; rorigin : predicate}


let zero ity = Integer {n = Z.zero; ity}

let one ity = Integer {n = Z.one; ity}

module Aux = struct

  let of_bool = function
    | true -> one (C_integer IInt)
    | false -> zero (C_integer IInt)

  let under_coerce e =
    match e.enode with
    | Coerce {coerced = e} -> e
    | _ -> e

  let of_exp_node ~origin ?(rtes=[]) enode = {enode; rtes; origin}

  let integer ~origin ~rtes ~ity n =
    of_exp_node ~origin ~rtes @@ Integer {n; ity}
end

module Pretty = struct
  open Format

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
       | Ne -> "!="
       | And -> "&&"
       | Or -> "||")

  let pp_unop fmt u =
    fprintf fmt "%s"
      (match u with
       | Neg -> "-"
       | Not -> "!")

  let rec pp_lhost fmt = function
    | Var vi -> Printer.pp_varinfo fmt vi
    | Mem exp -> fprintf fmt "*@[%a@]" pp_exp exp

  and pp_lval fmt (host, offset) =
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
    | Integer {ity; n} ->
      fprintf fmt "@[%a@]@ :@ @[%a@]" Z.pretty n Analyses_types.pp_number_ty ity;
    | UnOp {unop; op} ->
      fprintf fmt "@[%a@]@%a@" pp_unop unop pp_exp op
    | BinOp {binop; op1; op2} ->
      fprintf fmt "@[%a@]@ %a@ @[%a@]" pp_exp op1 pp_binop binop pp_exp op2
    | If {op1; op2; op3} ->
      fprintf fmt "if %a@ then @[%a@]@ else @[%a@]"
        pp_exp op1 pp_exp op2 pp_exp op3
    | Lval lval -> pp_lval fmt lval
    | SizeOf ty -> fprintf fmt "SizeOf(@[%a])" Printer.pp_typ ty
    | Coerce {coerce_to = ty; coerced = exp} ->
      fprintf fmt "Coerce(@[%a@],@ @[%a@])" Printer.pp_typ ty pp_exp exp

  let pp_rtes fmt rtes =
    let pp_rte fmt rte = fprintf fmt "%a" pp_exp_node rte.rnode in
    Pretty_utils.pp_list ~pre:"[" ~suf:"]" ~sep:";@ " pp_rte fmt rtes
end

exception No_opt

module Optimisation = struct
  open Aux

  let neg ~origin ~ity e =
    match e.enode with
    | Integer {n} ->
      of_exp_node ~origin ~rtes:e.rtes (Integer {n = Z.neg n; ity})
    | _ -> raise No_opt

  let lnot ~origin e =
    match e.enode with
    | Integer {n} when not @@ Z.is_zero n ->
      of_exp_node ~origin ~rtes:e.rtes (of_bool false)
    | Integer {n} when Z.is_zero n ->
      of_exp_node ~origin ~rtes:e.rtes (of_bool true)
    | _ -> raise No_opt

  let plus ~origin ~ity e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, _ when Z.is_zero z1 ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes) e2.enode
    | _, Integer {n = z2} when Z.is_zero z2 ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes) e1.enode
    | Integer {n = z1}, Integer {n = z2} ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.add z1 z2)
    | _ -> raise No_opt

  let minus ~origin ~ity e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, Integer {n = z2} when Z.is_zero z1 ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.neg z2)
    | _, Integer {n = z2} when Z.is_zero z2 ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes) e1.enode
    | Integer {n = z1}, Integer {n = z2} ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.sub z1 z2)
    | _ -> raise No_opt

  let mult ~origin ~ity e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, _ when Z.is_zero z1 ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.zero)
    | _, Integer {n = z2} when Z.is_zero z2 ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.zero)
    | Integer {n = z1}, _ when Z.is_one z1 ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes) e2.enode
    | _, Integer {n = z2} when Z.is_one z2 ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes) e1.enode
    | Integer {n = z1}, Integer {n = z2} ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.mul z1 z2)
    | _ -> raise No_opt


  let div ~origin ~ity e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, _ when Z.is_zero z1 ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.zero)
    | Integer {n = z1}, Integer {n = z2} when not (Z.is_zero z2) ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.div z1 z2)
    | _ -> raise No_opt

  let modulo ~origin ~ity e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, _ when Z.is_zero z1 ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.zero)
    | Integer {n = z1}, Integer {n = z2} when not (Z.is_zero z2) ->
      integer ~origin ~rtes:(e1.rtes @ e2.rtes) ~ity (Z.rem z1 z2)
    | _ -> raise No_opt

  let lt ~origin e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, Integer {n = z2} ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes)
        (of_bool @@ Z.lt z1 z2)
    | _ -> raise No_opt

  let gt ~origin e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, Integer {n = z2} ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes)
        (of_bool @@ Z.gt z1 z2)
    | _ -> raise No_opt

  let le ~origin e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, Integer {n = z2} ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes)
        (of_bool @@ Z.leq z1 z2)
    | _ -> raise No_opt

  let ge ~origin e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, Integer {n = z2} ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes)
        (of_bool @@ Z.geq z1 z2)
    | _ -> raise No_opt

  let eq ~origin e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, Integer {n = z2} ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes)
        (of_bool @@ Z.equal z1 z2)
    | _ -> raise No_opt

  let ne ~origin e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n = z1}, Integer {n = z2} ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes)
        (of_bool @@ not @@ Z.equal z1 z2)
    | _ -> raise No_opt

  let lconj ~origin e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n}, _ when Z.is_zero n ->
      of_exp_node ~origin ~rtes:(under_coerce e1).rtes (of_bool false)
    | Integer {n}, _ when not @@ Z.is_zero n ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes) e2.enode
    | _ -> raise No_opt

  let ldisj ~origin e1 e2 =
    match e1.enode, e2.enode with
    | Integer {n}, _ when not @@ Z.is_zero n ->
      of_exp_node ~origin ~rtes:(under_coerce e1).rtes (of_bool true)
    | Integer {n}, _ when Z.is_zero n ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes) e2.enode
    | _ -> raise No_opt

  let conditional ~origin e1 e2 e3 =
    match e1.enode with
    | Integer {n} when not @@ Z.is_zero n ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e2.rtes) e2.enode
    | Integer {n} when Z.is_zero n ->
      of_exp_node ~origin ~rtes:(e1.rtes @ e3.rtes) e3.enode
    | _ -> raise No_opt

  let unop ~origin uop ity e =
    let e = under_coerce e in
    match uop with
    | Neg -> neg ~origin ~ity e
    | Not -> lnot ~origin e

  let binop ~origin bop ity e1 e2 =
    let e1, e2 = under_coerce e1, under_coerce e2 in
    match bop with
    | Plus -> plus ~origin ~ity e1 e2
    | Minus -> minus ~origin ~ity e1 e2
    | Mult -> mult ~origin ~ity e1 e2
    | Div -> div ~origin ~ity e1 e2
    | Mod -> modulo ~origin ~ity e1 e2
    | Lt -> lt ~origin e1 e2
    | Gt -> gt ~origin e1 e2
    | Le -> le ~origin e1 e2
    | Ge -> ge ~origin e1 e2
    | Eq -> eq ~origin e1 e2
    | Ne -> ne ~origin e1 e2
    | And -> lconj ~origin e1 e2
    | Or -> ldisj ~origin e1 e2

  let conditional ~origin e1 e2 e3 =
    let e1, e2, e3 = under_coerce e1, under_coerce e2, under_coerce e3 in
    conditional ~origin e1 e2 e3
end

module Exp = struct
  open Aux

  let lval ~origin lval = of_exp_node ~origin @@ Lval lval
  let integer ~origin ~ity n = of_exp_node ~origin @@ Integer {ity; n}
  let sizeof ~origin ty = of_exp_node ~origin @@ SizeOf ty
  let rte rte =
    of_exp_node ~origin:(Analyses_types.PoT_pred rte.rorigin) rte.rnode

  let mk_true ~origin () = integer ~origin ~ity:(C_integer IInt) Z.one
  let mk_false ~origin () = integer ~origin ~ity:(C_integer IInt) Z.zero

  let try_optimise ~origin unopt_exp opt_exp =
    let orig = of_exp_node ~origin unopt_exp in
    if not @@ Options.Optimisations.Smart_il.get () then orig else
      try
        let res = opt_exp () in
        Options.debug ~dkey:Options.Dkey.interlang_print_opt ~level:3
          "@[%a@] => @[%a@]" Pretty.pp_exp orig Pretty.pp_exp res;
        res
      with No_opt -> orig

  let unop ~origin uop ity e =
    try_optimise ~origin
      (UnOp {unop = uop; ity; op = e})
      (fun () -> Optimisation.unop ~origin uop ity e)

  let binop ~origin bop ity e1 e2 =
    try_optimise ~origin
      (BinOp {binop = bop; ity; op1 = e1; op2 = e2})
      (fun () -> Optimisation.binop ~origin bop ity e1 e2)

  let conditional ~origin ity e1 e2 e3 =
    try_optimise ~origin
      (If {ity; op1 = e1; op2 = e2; op3 = e3})
      ((fun () -> Optimisation.conditional ~origin e1 e2 e3))

  let coerce ~origin ~coerce_to exp =
    match exp with
    | {enode = Coerce c; origin} as exp -> (* collapse stacked coercions *)
      {exp with origin; enode = Coerce {c with coerce_to}}
    | exp -> of_exp_node ~origin @@ Coerce {coerce_to; coerced = exp}
end

module Rte = struct
  let make p e = {rnode = e.enode; rorigin = p}
end

module Lhost = struct
  let var vi = Var vi
  let mem e = Mem e
end

module Helpers = struct
  let attach_rtes rtes e = {e with rtes = e.rtes @ rtes}
  let is_div_or_mod = function
    | (Div | Mod) -> true | _ -> false
end
