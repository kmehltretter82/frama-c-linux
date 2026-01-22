(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

type clause =
  | Body of logic_info
  | Prop of Property.t
  | Call of stmt * kernel_function * Property.t

let compare_clause a b =
  match a, b with
  | Body f , Body g -> Logic_info.compare f g
  | Body _ , _ -> (-1)
  | _ , Body _ -> (+1)
  | Prop f , Prop g -> Property.compare f g
  | Prop _ , _ -> (-1)
  | _ , Prop _ -> (+1)
  | Call(s1,kf1,p1) , Call(s2,kf2,p2) ->
    let c = Stmt.compare s1 s2 in
    if c <> 0 then c else
      let c = Kernel_function.compare kf1 kf2 in
      if c <> 0 then c else
        Property.compare p1 p2

type acs =
  | Exp of Stmt.t * exp
  | Lval of Stmt.t * lval
  | Init of Stmt.t * varinfo
  | Term of clause * term_lval

let compare a b =
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

  | Term(ca,ta), Term(cb,tb) ->
    let cmp = compare_clause ca cb in
    if cmp <> 0 then cmp else Term_lval.compare ta tb

let pp_label fmt (s : stmt) =
  match s.labels with
  | Label(l,_,_)::_ -> Format.pp_print_string fmt l
  | _ ->
    let loc, _ = Stmt.loc s in
    Format.fprintf fmt "L%d" loc.pos_lnum

let pp_clause fmt = function
  | Body l -> Format.pp_print_string fmt "logic:" ; Logic_info.pretty fmt l
  | Prop p -> Format.pp_print_string fmt @@ Property.Names.get_prop_name_id p
  | Call(st,kf,prop) ->
    Format.fprintf fmt "%a@%a@%s"
      Kernel_function.pretty kf pp_label st
      (Property.Names.get_prop_name_id prop)

let pretty fmt = function
  | Init(s,x) ->
    Format.fprintf fmt "%a@%a" Varinfo.pretty x pp_label s
  | Lval(s,l) ->
    Format.fprintf fmt "%a@%a" Lval.pretty l pp_label s
  | Exp(s,e) ->
    Format.fprintf fmt "(%a)@%a" Exp.pretty e pp_label s
  | Term(c,l) ->
    Format.fprintf fmt "(%a)@%a" Term_lval.pretty l pp_clause c


let ctype_of = function
  | Ctype t -> t
  | _ -> Cil_const.voidType

let location = function
  | Body _ -> Location.dummy (* TODO *)
  | Prop ip | Call(_,_,ip) -> Property.location ip

let typeof = function
  | Init(_,x) -> x.vtype
  | Lval(_,lv) -> Cil.typeOfLval lv
  | Exp(_,e) -> Cil.typeOf e
  | Term(_,lv) ->
    Logic_const.plain_or_set ctype_of @@ Cil.typeOfTermLval lv

module Set = Set.Make(struct type t = acs let compare = compare end)
