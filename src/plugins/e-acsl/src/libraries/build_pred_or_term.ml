(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2025                                               *)
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

open Cil_types

let relation_to_binop = function
  | Rlt -> Lt
  | Rgt -> Gt
  | Rle -> Le
  | Rge -> Ge
  | Req -> Eq
  | Rneq -> Ne

let mk_bool_term ~loc node =
  Logic_const.term ~loc node (Ctype Cil_const.boolType)

let rec term_of_pred p =
  let loc = p.pred_loc in
  match p.pred_content with
  | Prel (rel, tl, tr) ->
    let op = relation_to_binop rel in
    mk_bool_term ~loc (TBinOp (op, tl, tr))
  | Pand (pl, pr) ->
    let tl = term_of_pred pl in
    let tr = term_of_pred pr in
    mk_bool_term ~loc (TBinOp (LAnd, tl, tr))
  | Por (pl, pr) ->
    let tl = term_of_pred pl in
    let tr = term_of_pred pr in
    mk_bool_term ~loc (TBinOp (LOr, tl, tr))
  | Papp (({ l_body = LBpred _; _ } as li), labels, args) ->
    mk_bool_term ~loc (Tapp (li, labels, args))
  | _ ->
    Options.fatal "Cannot convert predicate '%a' to term" Printer.pp_predicate p

module type S = sig
  type t

  val mk_false : logic_type option -> t
  val mk_true : logic_type option -> t
  val mk_logic_body : t -> logic_body
  val mk_let : ?loc:location -> logic_info -> t -> t
  val mk_if : ?loc:location -> predicate -> t -> t -> t
  val mk_at : logic_label -> t -> t

  val visit : Visitor.frama_c_visitor -> t -> t
end

module Predicate : S with type t = predicate = struct
  type t = predicate

  let mk_false = function
    | None -> Logic_const.pfalse
    | Some _ -> Options.fatal "cannot specify a type for building a predicate"

  let mk_true = function
    | None -> Logic_const.ptrue
    | Some _ -> Options.fatal "cannot specify a type for building a predicate"

  let mk_logic_body pred = LBpred pred

  let mk_let = Logic_const.plet

  let mk_if ?loc p_cond t_true t_false =
    match (t_true.pred_content, t_false.pred_content) with
    (* cond ? \true : \false  ≡  cond *)
    | Ptrue, Pfalse -> p_cond
    (* cond ? \true : f  ≡  cond || f *)
    | Ptrue, _ -> Logic_const.por ?loc (p_cond, t_false)
    (* cond ? t : \false  ≡  cond && t *)
    | _, Pfalse -> Logic_const.pand ?loc (p_cond, t_true)
    | _ ->
      let cond = term_of_pred p_cond in
      Logic_const.pif (cond, t_true, t_false)

  let mk_at labels p = {p with pred_content = Pat (p, labels)}

  let visit = Visitor.visitFramacPredicate
end

module Term : S with type t = term = struct
  type t = term

  let mk_false = function
    | None -> Options.fatal "must specify a type for building a term"
    | Some l_type ->
      let default = Logic_const.tinteger 0 in
      Logic_const.term (TCast (true, l_type, default)) l_type

  let mk_true = function
    | None -> Options.fatal "must specify a type for building a term"
    | Some l_type ->
      let default = Logic_const.tinteger 1 in
      Logic_const.term (TCast (true, l_type, default)) l_type

  let mk_logic_body term = LBterm term

  let mk_let ?loc li t = Logic_const.term ?loc (Tlet (li, t)) t.term_type

  let mk_if ?loc p_cond t_true t_false =
    let t_cond = term_of_pred p_cond in
    Logic_const.term ?loc (Tif (t_cond, t_true, t_false)) t_true.term_type

  let mk_at labels p = {p with term_node = Tat (p, labels)}

  let visit = Visitor.visitFramacTerm
end
