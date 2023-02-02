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

let rec type_of_offset basetyp = function
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

let type_of_exp e =
  match e.origin with
  | Exp exp -> Cil.typeOf exp
  | Term _ -> assert false

let type_of_lval (host, offset) =
  let basetyp = match host with
    | Var vi -> vi.vtype
    | Mem addr -> Cil.typeOf_pointed (type_of_exp addr)
  in
  type_of_offset basetyp offset

let origin_exp e =
  match e.origin with
  | Exp exp -> exp
  | Term _ -> invalid_arg "origin is not an expression"

let [@tail_mod_cons] rec origin_offset = function
  | NoOffset -> Cil_types.NoOffset
  | Index (e, o) -> Cil_types.Index (origin_exp e, origin_offset o)
  | Field (fi, o) -> Cil_types.Field (fi, origin_offset o)

let origin_lval = function
  | Var v, o -> Cil_types.Var v, origin_offset o
  | Mem e, o -> Cil_types.Mem (origin_exp e), origin_offset o
