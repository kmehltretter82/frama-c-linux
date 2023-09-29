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


(* --- Type of --- *)

include Evast_typing


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

let loc exp =
  match exp.origin with
  | Exp exp -> Some (exp.Cil_types.eloc)
  | Built | Term _ -> None


(* --- Rewriting --- *)

let rec rewrite_exp f exp =
  f ~descend:(descend f) exp
and descend f exp =
  let replace_if condition node =
    if condition then Evast_builder.mk node else exp
  in
  match exp.node with
  | Lval (lh, o as lv) ->
    let (lh', o' as lv') = rewrite_lval f lv in
    replace_if (lh' != lh || o' != o) (Lval lv')
  | AddrOf (lh, o as lv) ->
    let (lh', o' as lv') = rewrite_lval f lv in
    replace_if (lh' != lh || o' != o) (AddrOf lv')
  | StartOf (lh, o as lv) ->
    let (lh', o' as lv') = rewrite_lval f lv in
    replace_if (lh' != lh || o' != o) (StartOf lv')
  | UnOp (op, e, t) ->
    let e' = rewrite_exp f e in
    replace_if (e' != e) (UnOp (op, e', t))
  | BinOp (op, e1, e2, t) ->
    let e1' = rewrite_exp f e1
    and e2' = rewrite_exp f e2 in
    replace_if (e1' != e1 || e2' != e2) (BinOp (op, e1', e2', t))
  | CastE (t, e) ->
    let e' = rewrite_exp f e in
    replace_if (e' != e) (CastE (t, e'))
  | SizeOfE e ->
    let e' = rewrite_exp f e in
    replace_if (e' != e)  (SizeOfE e')
  | AlignOfE e ->
    let e' = rewrite_exp f e in
    replace_if (e' != e) (AlignOfE e')
  | SizeOf _ | Const _ | SizeOfStr _ | AlignOf _ ->
    exp
and rewrite_lval f (lhost, offset) =
  rewrite_lhost f lhost, rewrite_offset f offset
and rewrite_lhost f lhost =
  match lhost with
  | Var _ -> lhost
  | Mem e ->
    let e' = rewrite_exp f e in
    if e' != e then Mem e' else lhost
and rewrite_offset f offset =
  match offset with
  | NoOffset -> offset
  | Field (fi, o) ->
    let o' = rewrite_offset f o in
    if o' != o then Field (fi, o') else offset
  | Index (e, o) ->
    let e' = rewrite_exp f  e
    and o' = rewrite_offset f o in
    if e != e' || o' != o then Index (e', o') else offset


let const_fold exp =
  let f ~descend exp =
    match exp.origin with
    | Exp e ->
      let e' = Cil.constFold true e in
      Evast_builder.translate_exp e'
    | _ ->
      descend exp
  in
  rewrite_exp f exp


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
  Cil.isVolatileType (Evast_typing.type_of_lval lval) ||
  lhost_contains_volatile lhost ||
  offset_contains_volatile offset
and lhost_contains_volatile : lhost -> bool = function
  | Var _ -> false
  | Mem e -> exp_contains_volatile e
and offset_contains_volatile : offset -> bool = function
  | NoOffset -> false
  | Field (_, o) -> offset_contains_volatile o
  | Index (e, o) -> offset_contains_volatile o || exp_contains_volatile e


(* --- Vars lookup --- *)

module VarSet = Cil_datatype.Varinfo.Set

let rec vars_in_exp (exp : exp) : VarSet.t =
  match exp.node with
  | Lval lv | AddrOf lv | StartOf lv  -> vars_in_lval lv
  | UnOp (_, e, _) | CastE (_, e) -> vars_in_exp e
  | BinOp (_, e1, e2, _) -> VarSet.union (vars_in_exp e1) (vars_in_exp e2)
  | _ -> VarSet.empty
and vars_in_lval (lhost, offset : lval) : VarSet.t =
  VarSet.union (vars_in_lhost lhost) (vars_in_offset offset)
and vars_in_lhost : lhost -> VarSet.t = function
  | Var vi -> VarSet.singleton vi
  | Mem e -> vars_in_exp e
and vars_in_offset : offset -> VarSet.t = function
  | NoOffset -> VarSet.empty
  | Field (_, o) -> vars_in_offset o
  | Index (e, o) -> VarSet.union (vars_in_offset o) (vars_in_exp e)


(* Dependencies *)

let rec deps_of_exp find_loc exp =
  let rec process exp = match exp.node with
    | Lval lval ->
      deps_of_lval find_loc lval
    | UnOp (_, e, _) | CastE (_, e) ->
      process e
    | BinOp (_, e1, e2, _) ->
      Deps.join (process e1) (process e2)
    | StartOf lv | AddrOf lv ->
      Deps.data (indirect_zone_of_lval find_loc lv)
    | Const _ | SizeOf _ | AlignOf _ | SizeOfStr _ | SizeOfE _ | AlignOfE _ ->
      Deps.bottom
  in
  process exp

and zone_of_exp find_loc exp = Deps.to_zone (deps_of_exp find_loc exp)

and deps_of_lval find_loc lval =
  let ploc = find_loc lval in
  (* dereference of an lvalue: first, its address must be computed,
     then its contents themselves are read *)
  let indirect = indirect_zone_of_lval find_loc lval in
  let data = Precise_locs.enumerate_valid_bits Read ploc in
  { Deps.data ; indirect }

(* Computations of the inputs of a lvalue : union of the "host" part and
   the offset. *)
and indirect_zone_of_lval find_loc (lhost, offset) =
  Locations.Zone.join
    (zone_of_lhost find_loc lhost) (zone_of_offset find_loc offset)

(* Computation of the inputs of a host. Nothing for a variable, and the
   inputs of [e] for a dereference [*e]. *)
and zone_of_lhost find_loc = function
  | Var _ -> Locations.Zone.bottom
  | Mem e -> zone_of_exp find_loc e

(* Computation of the inputs of an offset. *)
and zone_of_offset find_loc = function
  | NoOffset -> Locations.Zone.bottom
  | Field (_, o) -> zone_of_offset find_loc o
  | Index (e, o) ->
    Locations.Zone.join
      (zone_of_exp find_loc e) (zone_of_offset find_loc o)
