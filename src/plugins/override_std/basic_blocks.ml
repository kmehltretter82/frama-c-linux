(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

open Cil
open Cil_types
open Cil_const
open Logic_const

let ptr_of t = TPtr(t, [])
let const_of t = Cil.typeAddAttributes [Attr("const", [])] t
let restrict_of t = Cil.typeAddAttributes [Attr("restrict", [])] t

let size_t () =
  Globals.Types.find_type Logic_typing.Typedef "size_t"

let rec string_of_typ_aux = function
  | TInt(IBool, _) -> "bool"
  | TInt(IChar, _) -> "char"
  | TInt(ISChar, _) -> "schar"
  | TInt(IUChar, _) -> "uchar"
  | TInt(IInt, _) -> "int"
  | TInt(IUInt, _) -> "uint"
  | TInt(IShort, _) -> "short"
  | TInt(IUShort, _) -> "ushort"
  | TInt(ILong, _) -> "long"
  | TInt(IULong, _) -> "ulong"
  | TInt(ILongLong, _) -> "llong"
  | TInt(IULongLong, _) -> "ullong"
  | TFloat(FFloat, _) -> "float"
  | TFloat(FDouble, _) -> "double"
  | TFloat(FLongDouble, _) -> "ldouble"
  | TPtr(t, _) -> "ptr_" ^ string_of_typ t
  | TEnum (ei, _) -> ei.ename
  | TComp (ci, _, _) -> ci.cname
  | TArray (t, _, _, _) -> "arr_" ^ string_of_typ t
  | _ -> assert false
and string_of_typ t = string_of_typ_aux (Cil.unrollType t)


let size_var t value = {
  l_var_info = make_logic_var_local "__fc_len" t;
  l_type = Some t;
  l_tparams = [];
  l_labels = [];
  l_profile = [];
  l_body = LBterm value;
}

(** Features related to terms *)

let cvar_to_tvar vi = tvar (cvar_to_lvar vi)

let tminus ?loc t1 t2 =
  let minus, typ = match t1.term_type, t2.term_type with
    | Ctype(t1), Ctype(t2) when Cil.isPointerType t1 && Cil.isPointerType t2 ->
      MinusPP, Linteger
    | Ctype(t), _ when Cil.isPointerType t ->
      MinusPI, Ctype(t)
    | t, _ ->
      MinusA, t
  in
  term ?loc (TBinOp(minus, t1, t2)) typ

let tplus ?loc t1 t2 =
  let plus = match t1.term_type with
    | Ctype(t) when Cil.isPointerType t -> PlusPI
    | _ -> PlusA
  in
  term ?loc (TBinOp(plus, t1, t2)) t1.term_type

let tdivide ?loc t1 t2 =
  term ?loc (TBinOp(Div, t1, t2)) t1.term_type

let ttype_of_pointed = function
  | Ctype(TPtr(t, _)) | Ctype(TArray(t, _, _, _)) -> Ctype t
  | _ -> assert false

let tbuffer_range ?loc ptr len =
  let last = tminus ?loc len (tinteger ?loc 1) in
  let range = trange ?loc (Some (tinteger ?loc 0), Some last) in
  tplus ?loc ptr range

let tunref_range ?loc ptr len =
  let typ = ttype_of_pointed ptr.term_type in
  let range = tbuffer_range ?loc ptr len in
  term (TLval ((TMem range), TNoOffset)) typ

let tsizeofpointed ?loc = function
  | Ctype(TPtr(t, _)) | Ctype(TArray(t, _, _, _)) -> tinteger ?loc (Cil.bytesSizeOf t)
  | _ -> assert false

let tlen_div_size ?loc t bytes_len =
  let sizeof = tsizeofpointed ?loc t in
  tdivide ?loc bytes_len sizeof

(** Features related to predicates *)

let plet_len_div_size ?loc t bytes_len pred =
  let len = tlen_div_size t bytes_len in
  let len_var = size_var Linteger len in
  plet ?loc len_var (pred (tvar len_var.l_var_info))

let pgeneric_valid_buffer ?loc validity lbl ptr len =
  let buffer = tbuffer_range ?loc ptr len in
  validity ?loc (lbl, buffer)

let pgeneric_valid_len_bytes ?loc validity lbl ptr bytes_len =
  plet_len_div_size ?loc ptr.term_type bytes_len (pgeneric_valid_buffer ?loc validity lbl ptr)

let pvalid_len_bytes ?loc = pgeneric_valid_len_bytes ?loc pvalid
let pvalid_read_len_bytes ?loc = pgeneric_valid_len_bytes ?loc pvalid_read

let pcorrect_len_bytes ?loc t bytes_len =
  let sizeof = tsizeofpointed ?loc t in
  let modulo = term ?loc (TBinOp(Mod, bytes_len, sizeof)) Linteger in
  prel ?loc (Req, modulo, tinteger ?loc 0)

let pseparated_memories ?loc p1 len1 p2 len2 =
  let b1 = tbuffer_range ?loc p1 len1 in
  let b2 = tbuffer_range ?loc p2 len2 in
  pseparated ?loc [ b1 ; b2 ]
