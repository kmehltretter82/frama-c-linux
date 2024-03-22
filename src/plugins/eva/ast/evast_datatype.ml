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

open Evast_types

module Typ = Cil_datatype.Typ
module Varinfo = Cil_datatype.Varinfo


(** Hashing functions  *)

let rec hash_lval lv =
  let (h,o) = lv.node in
  Hashtbl.hash (hash_lhost h, hash_offset o)
and hash_lhost = function
  | Var v -> Hashtbl.hash (1, Varinfo.hash v)
  | Mem e -> Hashtbl.hash (2, hash_exp e)
and hash_offset = function
  | NoOffset -> Hashtbl.hash (1, ())
  | Index (e, o) -> Hashtbl.hash (2, hash_exp e, hash_offset o)
  | Field (f, o) -> Hashtbl.hash (3, f.forder, hash_offset o)
and hash_exp e =
  match e.node with
  | Const c -> Hashtbl.hash (1, hash_constant c)
  | Lval lv -> Hashtbl.hash (2, hash_lval lv)
  | UnOp (op, e, ty) ->
    Hashtbl.hash (8, op, hash_exp e, Typ.hash ty)
  | BinOp (op, e1, e2, ty) ->
    Hashtbl.hash (9, op, hash_exp e1, hash_exp e2, Typ.hash ty)
  | CastE (ty, e) -> Hashtbl.hash (10, Typ.hash ty, hash_exp e)
  | AddrOf lv -> Hashtbl.hash (11, hash_lval lv)
  | StartOf lv -> Hashtbl.hash (12, hash_lval lv)
and hash_constant c =
  match c with
  | CTopInt t -> Hashtbl.hash (1, Typ.hash t)
  | CString _ | CChr _ -> Hashtbl.hash (2, c)
  | CReal (fn, fk, _) -> Hashtbl.hash (3, fn, fk)
  | CInt64 (n, k, _) -> Hashtbl.hash (4, n, k )
  | CEnum (ei, _) -> Hashtbl.hash (5, ei.einame)


(* Tag utility *)

let reprs_tag = List.map (fun node -> {node; typ=Cil.voidType; origin=Built})


(* Exported modules *)

module Lval =
  Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = lval
    let name = "Evast_datatype.Lval"
    let compare = compare_lval
    let equal = equal_lval
    let hash = hash_lval
    let reprs =
      reprs_tag (List.map (fun v -> Var v, NoOffset) Cil_datatype.Varinfo.reprs)
    let pretty = Evast_printer.pp_lval
  end)

module Lhost =
  Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = lhost
    let name = "Evast_datatype.Lhost"
    let compare = compare_lhost
    let equal = equal_lhost
    let hash = hash_lhost
    let reprs = List.map (fun v -> Var v) Cil_datatype.Varinfo.reprs
    let pretty fmt h =
      let lv = Evast_builder.mk_lval (h, NoOffset) in
      Evast_printer.pp_lval fmt lv
  end)

module Offset = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = offset
    let name = "Evast_datatype.Offset"
    let compare = compare_offset
    let equal = equal_offset
    let hash = hash_offset
    let reprs = [NoOffset]
    let pretty = Evast_printer.pp_offset
  end)

module Exp = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = exp
    let name = "Evast_datatype.Exp"
    let compare = compare_exp
    let equal = equal_exp
    let hash = hash_exp
    let reprs =
      List.map (fun e -> Evast_builder.translate_exp e) Cil_datatype.Exp.reprs
    let pretty = Evast_printer.pp_exp
  end)

module Constant = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = constant
    let name = "Evast_datatype.Constant"
    let compare = compare_constant
    let equal = equal_constant
    let hash = hash_constant
    let reprs = [ CInt64(Integer.zero, IInt, Some "0") ]
    let pretty = Evast_printer.pp_constant
  end)
