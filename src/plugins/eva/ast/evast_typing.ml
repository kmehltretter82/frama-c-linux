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

let type_of_lhost = function
  | Var x -> x.vtype
  | Mem e -> Cil.typeOf_pointed (type_of_exp e)
