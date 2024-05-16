(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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
open Cil_datatype

let nul_exp = Cil.kinteger64 ~loc:Location.unknown ~repr:"0.." ~kind:IInt Integer.zero
let is_nul_exp = Cil_datatype.ExpStructEq.equal nul_exp

module HL = Lval.Hashtbl
module HE = Exp.Hashtbl

let cached_lval = HL.create 23
let cached_exp = HE.create 37

let clear_cache () =
  HL.clear cached_lval;
  HE.clear cached_exp

exception Explicit_pointer_address of location

let check_cast_compatibility e typ =
  let type_of_e = Cil.typeOf e in
  (* emit a warning for unsafe casts, but not for the NULL pointer *)
  if Cil.need_cast typ type_of_e && not (Cil.isZero e) then
    Options.warning
      ~once:true
      ~source:(fst @@ e.eloc)
      ~wkey:Options.Warn.unsafe_cast
      "unsafe cast from %a to %a; analysis may be unsound"
      Printer.pp_typ type_of_e Printer.pp_typ typ

let rec simplify_offset o =
  match o with
  | NoOffset -> NoOffset
  | Field(f,o) -> Field(f, simplify_offset o)
  | Index(_e,o) -> Index(nul_exp, simplify_offset o)

let rec simplify_lval (h,o) =
  try HL.find cached_lval (h,o)
  with Not_found ->
    let res = (simplify_host h, simplify_offset o) in
    HL.add cached_lval (h,o) res;
    res

and simplify_host h =
  match h with
  | Var _ -> h
  | Mem e ->
    let simp_e = simplify_exp e in
    if is_nul_exp simp_e
    then raise (Explicit_pointer_address e.eloc)
    else Mem simp_e

and simplify_exp e =
  try
    HE.find cached_exp e
  with Not_found ->
    let res =
      match e.enode with
      | CastE (typ, e) ->
        check_cast_compatibility e typ;
        simplify_exp e
      | Lval lv -> {e with enode = Lval (simplify_lval lv)}
      | StartOf lv -> {e with enode = Lval (simplify_lval lv)}
      | AddrOf lv -> {e with enode = AddrOf (simplify_lval lv)}
      | BinOp(PlusPI, e1, _, _) | BinOp(MinusPI, e1, _, _) ->
        begin
          match (simplify_exp e1).enode with
          | Lval _ | AddrOf _ as node -> {e with enode = node}
          | _ -> raise (Explicit_pointer_address e1.eloc)
        end
      | _ -> e
    in
    HE.add cached_exp e res;
    Options.debug ~level:9 "simplify_exp %a = %a"
      Printer.pp_exp e Printer.pp_exp res;
    res

module LvalOrRef = struct
  type t = Lval of lval | Ref of lval

  let pretty l =
    let print f fmt x =
      match x with
      | Lval lv -> f fmt lv
      | Ref lv -> Format.fprintf fmt "&%a" f lv
    in
    if Options.is_debug_key_enabled Options.DebugKeys.lvals
    then print Cil_types_debug.pp_lval l
    else print Printer.pp_lval l

  let from_exp e =
    let e = simplify_exp e in
    match e.enode with
      Lval lv -> Some (Lval lv)
    | AddrOf lv -> Some (Ref lv)
    | _ -> None
end

module Lval = struct
  let simplify = simplify_lval
end
