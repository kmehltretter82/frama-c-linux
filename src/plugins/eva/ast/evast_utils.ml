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

type typ = Cil_types.typ

(* --- Type of --- *)

let rec type_of_offset (basetyp : typ) : offset -> typ = function
  | NoOffset -> basetyp
  | Index (_, o) ->
    type_of_offset (Cil.typeOf_array_elem basetyp) o
  | Field (fi, o) ->
    let base_attrs = Cil.filter_qualifier_attributes (Cil.typeAttrs basetyp) in
    let base_attrs =
      if Cil.hasAttribute Cil.frama_c_mutable fi.fattr then
        Cil.dropAttribute "const" base_attrs
      else
        base_attrs
    in
    type_of_offset (Cil.typeAddAttributes base_attrs fi.ftype) o

let rec type_of_lval (host, offset : lval) : typ =
  let basetyp = match host with
    | Var vi -> vi.vtype
    | Mem addr -> Cil.typeOf_pointed (type_of_exp addr)
  in
  type_of_offset basetyp offset

and type_of_exp (exp : exp) : typ =
  match exp.node with (* TODO: rely more on Cil by storing the Frama-C infered type on Evast const nodes ? *)
  | Const c -> type_of_const c
  | Lval lv -> Cil.type_remove_qualifier_attributes (type_of_lval lv)
  | SizeOf _ | SizeOfE _ | SizeOfStr _ -> Cil.theMachine.typeOfSizeOf
  | AlignOf _ | AlignOfE _ -> Cil.theMachine.typeOfSizeOf
  | UnOp (_, _, t) -> t
  | BinOp (_, _, _, t) -> t
  | CastE (t, _) -> t
  | AddrOf (lv) -> TPtr (type_of_lval lv, [])
  | StartOf (lv) ->
    match Cil.unrollType (type_of_lval lv) with
    | TArray (t,_,attrs) -> TPtr(t, attrs)
    | _ ->  assert false

and type_of_const : constant -> typ = function
  | CInt64 (_, ik, _) -> Cil_types.TInt (ik, [])
  | CChr _ -> Cil.intType
  | CString (String (_, Base.CSString _)) -> Cil.theMachine.stringLiteralType
  | CString (String (_, Base.CSWstring _)) -> TPtr (Cil.theMachine.wcharType, [])
  | CString (_) -> assert false (* it must be a String base*)
  | CReal (_, fk, _) -> TFloat (fk, [])
  | CEnum {eival=e} -> Cil.typeOf e


(* --- Origins --- *)

let origin_exp e =
  match e.origin with
  | Exp exp -> exp
  | Built | Term _ -> invalid_arg "origin is not an expression"

let [@tail_mod_cons] rec origin_offset = function
  | NoOffset -> Cil_types.NoOffset
  | Index (e, o) -> Cil_types.Index (origin_exp e, origin_offset o)
  | Field (fi, o) -> Cil_types.Field (fi, origin_offset o)

let origin_lval = function
  | Var v, o -> Cil_types.Var v, origin_offset o
  | Mem e, o -> Cil_types.Mem (origin_exp e), origin_offset o


(* --- Rewriting --- *)

let rewrite f exp =
  let rec rewrite_exp exp =
    f ~descend exp
  and descend exp =
    let replace_if condition node =
      if condition then Evast_builder.mk node else exp
    in
    match exp.node with
    | Lval (lh, o as lv) ->
      let (lh', o' as lv') = rewrite_lval lv in
      replace_if (lh' != lh || o' != o) (Lval lv')
    | AddrOf (lh, o as lv) ->
      let (lh', o' as lv') = rewrite_lval lv in
      replace_if (lh' != lh || o' != o) (AddrOf lv')
    | StartOf (lh, o as lv) ->
      let (lh', o' as lv') = rewrite_lval lv in
      replace_if (lh' != lh || o' != o) (StartOf lv')
    | UnOp (op, e, t) ->
      let e' = rewrite_exp e in
      replace_if (e' != e) (UnOp (op, e', t))
    | BinOp (op, e1, e2, t) ->
      let e1' = rewrite_exp e1
      and e2' = rewrite_exp e2 in
      replace_if (e1' != e1 || e2' != e2) (BinOp (op, e1', e2', t))
    | CastE (t, e) ->
      let e' = rewrite_exp e in
      replace_if (e' != e) (CastE (t, e'))
    | SizeOfE e ->
      let e' = rewrite_exp e in
      replace_if (e' != e)  (SizeOfE e')
    | AlignOfE e ->
      let e' = rewrite_exp e in
      replace_if (e' != e) (AlignOfE e')
    | SizeOf _ | Const _ | SizeOfStr _ | AlignOf _ ->
      exp
  and rewrite_lval (lhost, offset) =
    rewrite_lhost lhost, rewrite_offset offset
  and rewrite_lhost lhost =
    match lhost with
    | Var _ -> lhost
    | Mem e ->
      let e' = rewrite_exp e in
      if e' != e then Mem e' else lhost
  and rewrite_offset offset =
    match offset with
    | NoOffset -> offset
    | Field (fi, o) ->
      let o' = rewrite_offset o in
      if o' != o then Field (fi, o') else offset
    | Index (e, o) ->
      let e' = rewrite_exp e
      and o' = rewrite_offset o in
      if e != e' || o' != o then Index (e', o') else offset
  in
  rewrite_exp exp

let const_fold exp =
  let f ~descend exp =
    match exp.origin with
    | Exp e ->
      let e' = Cil.constFold true e in
      Evast_builder.translate_expr e'
    | _ ->
      descend exp
  in
  rewrite f exp


(* --- Heights --- *)

let rec height_exp exp =
  match exp.node with
  | Const _ | SizeOf _ | SizeOfStr _ | AlignOf _ -> 0
  | Lval lv | AddrOf lv | StartOf lv  -> height_lval lv + 1
  | UnOp (_,e,_) | CastE (_, e) | SizeOfE e | AlignOfE e
    -> height_exp e + 1
  | BinOp (_,e1,e2,_) -> max (height_exp e1) (height_exp e2) + 1

and height_lval (host, offset) =
  let h1 = match host with
    | Var _ -> 0
    | Mem e -> height_exp e + 1
  in
  max h1 (height_offset offset) + 1

and height_offset = function
  | NoOffset  -> 0
  | Field (_,r) -> height_offset r + 1
  | Index (e,r) -> max (height_exp e) (height_offset r) + 1


(* --- Relation inversion --- *)

let invert_relation : Evast.binop -> Evast.binop = function
  | Gt -> Le
  | Lt -> Ge
  | Le -> Gt
  | Ge -> Lt
  | Eq -> Ne
  | Ne -> Eq
  | _ -> assert false


(* --- Volatiles lookup --- *)

let rec exp_contains_volatile (exp : exp) : bool =
  match exp.node with
  | Lval lv | AddrOf lv | StartOf lv  -> lval_contains_volatile lv
  | UnOp (_, e, _) | CastE (_, e) -> exp_contains_volatile e
  | BinOp (_, e1, e2, _) -> exp_contains_volatile e1 || exp_contains_volatile e2
  | _ -> false
and lval_contains_volatile (lhost, offset as lval : lval) : bool =
  Cil.isVolatileType (type_of_lval lval) ||
  lhost_contains_volatile lhost ||
  offset_contains_volatile offset
and lhost_contains_volatile : lhost -> bool = function
  | Var _ -> false
  | Mem e -> exp_contains_volatile e
and offset_contains_volatile : offset -> bool = function
  | NoOffset -> false
  | Field (_, o) -> offset_contains_volatile o
  | Index (e, o) -> offset_contains_volatile o || exp_contains_volatile e
