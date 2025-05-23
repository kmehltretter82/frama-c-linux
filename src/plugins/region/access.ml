(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

type acs =
  | Exp of Stmt.t * exp
  | Lval of Stmt.t * lval
  | Init of Stmt.t * varinfo
  | Term of Property.t * term_lval

let compare (a : acs) (b : acs) : int =
  match a, b with
  | Init(sa,xa), Init(sb,xb) ->
    let cmp = Stmt.compare sa sb in
    if cmp <> 0 then cmp else Varinfo.compare xa xb
  | Init _ , _ -> (-1)
  | _ , Init _ -> (+1)

  | Lval(sa,la), Lval(sb,lb) ->
    let cmp = Stmt.compare sa sb in
    if cmp <> 0 then cmp else Lval.compare la lb
  | Lval _ , _ -> (-1)
  | _ , Lval _ -> (+1)

  | Exp(sa,ea), Exp(sb,eb) ->
    let cmp = Stmt.compare sa sb in
    if cmp <> 0 then cmp else Exp.compare ea eb
  | Exp _ , _ -> (-1)
  | _ , Exp _ -> (+1)

  | Term(sa,ta), Term(sb,tb) ->
    let cmp = Property.compare sa sb in
    if cmp <> 0 then cmp else Term_lval.compare ta tb

let pstmt fmt (s : stmt) =
  match s.labels with
  | Label(l,_,_)::_ -> Format.pp_print_string fmt l
  | _ ->
    let loc, _ = Stmt.loc s in
    Format.fprintf fmt "L%d" loc.pos_lnum

let pretty fmt = function
  | Init(s,x) ->
    Format.fprintf fmt "%a@%a" Varinfo.pretty x pstmt s
  | Exp(s,e) ->
    Format.fprintf fmt "%a@%a" Exp.pretty e pstmt s
  | Lval(s,l) ->
    Format.fprintf fmt "%a@%a" Lval.pretty l pstmt s
  | Term(s,l) ->
    Format.fprintf fmt "%a@%s" Term_lval.pretty l
      (Property.Names.get_prop_name_id s)

let ctype_of = function
  | Ctype t -> t
  | _ -> Cil_const.voidType

let typeof = function
  | Init(_,x) -> x.vtype
  | Lval(_,lv) -> Cil.typeOfLval lv
  | Exp(_,e) -> Cil.typeOf e
  | Term(_,lv) ->
    Logic_const.plain_or_set ctype_of @@ Cil.typeOfTermLval lv

module Set = Set.Make(struct type t = acs let compare = compare end)
