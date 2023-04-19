(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2023                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

open Cil_datatype

let nul_exp=
  let loc = Location.unknown in
  Cil.zero ~loc

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
      "unsafe cast from %a to %a"
      Printer.pp_typ type_of_e Printer.pp_typ typ

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

and simplify_offset o =
  match o with
  | NoOffset -> NoOffset
  | Field(f,o) -> Field(f, simplify_offset o)
  | Index(_e,o) -> Index(nul_exp, simplify_offset o)

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
      | AddrOf lv | StartOf lv -> {e with enode = AddrOf (simplify_lval lv)}
      | BinOp(PlusPI, e1, _, _) | BinOp(MinusPI, e1, _, _) ->
        begin
          match (simplify_exp e1).enode with
          | Lval _ | AddrOf _ as node -> {e with enode = node}
          | _ -> raise (Explicit_pointer_address e1.eloc)
        end
      | _ -> e
    in
    HE.add cached_exp e res;
    res

type simplified_lval =
  | BLval of lval
  | BAddrOf of lval

module Simplified_lval = struct

  type t = simplified_lval

  let from_lval lv =
    BLval (simplify_lval lv)

  let from_exp e =
    let e = simplify_exp e in
    match e.enode with
      Lval lv -> Some (BLval lv)
    | AddrOf lv -> Some (BAddrOf lv)
    | _ -> None

  let compare x1 x2 =
    match (x1,x2) with
    | (BLval lv1, BLval lv2) -> Cil_datatype.LvalStructEq.compare lv1 lv2
    | (BLval _, _) -> -1
    | (_, BLval _) -> 1
    | (BAddrOf lv1, BAddrOf lv2) -> Cil_datatype.LvalStructEq.compare lv1 lv2

  let print f fmt x =
    match x with
    | BLval lv -> f fmt lv
    | BAddrOf lv -> Format.fprintf fmt "&%a" f lv

  let pretty l =
    if Options.is_debug_key_enabled Options.DebugKeys.lvals
    then print Cil_types_debug.pp_lval l
    else print Printer.pp_lval l

  let removeOffsetLval x =
    match x with
    | BLval lv -> let lv,o = Cil.removeOffsetLval lv in BLval lv, o
    | BAddrOf lv -> let lv,o = Cil.removeOffsetLval lv in BAddrOf lv, o

  let addOffsetLval o x =
    match x with
    | BLval lv -> let lv = Cil.addOffsetLval o lv in BLval lv
    | BAddrOf lv -> let lv = Cil.addOffsetLval o lv in BAddrOf lv

  let points_to x =
    match x with
    | BAddrOf lv -> BLval lv
    | BLval lv ->
      BLval (Mem (Cil.dummy_exp (Lval lv)), NoOffset)

  let is_pointer x =
    match x with
    | BAddrOf _ -> true
    | BLval lv ->
      let t = Cil.typeOfLval lv in
      match Cil.unrollType t with
        TPtr _ | TArray _ -> true
      | _ -> false
end

module Simplified_lmap =
struct
  include Map.Make (Simplified_lval)

  let print (f_key: Format.formatter -> key -> unit) (f_val : Format.formatter -> 'a -> unit) fmt (m: 'a t) =
    let is_first = ref true in
    Format.fprintf fmt "{@[<hov 2>";
    iter (fun k v ->
        if not !is_first
        then
          Format.fprintf fmt ",@,"
        else
          is_first := false;
        Format.fprintf fmt " %a -> %a" f_key k f_val v
      )
      m;
    Format.fprintf fmt " @]}"

  let pretty f fmt m = print Simplified_lval.pretty f fmt m
end

module Simplified_lset =
struct
  include Set.Make (Simplified_lval)

  let print (f_elt: Format.formatter -> elt -> unit) fmt (m: t) =
    let is_first = ref true in
    Format.fprintf fmt "{@[";
    iter (fun e ->
        if !is_first
        then
          is_first := false
        else
          Format.fprintf fmt ",@ ";
        Format.fprintf fmt "%a" f_elt e
      )
      m;
    Format.fprintf fmt "@]}"

  let pretty fmt s = print Simplified_lval.pretty fmt s

  let fold_lval f s init =
    let f_fold lv acc =
      match lv with
      | BLval lv -> f lv acc
      | BAddrOf lv -> f lv acc
    in
    fold f_fold s init
end

let decompose_lval (lv1: Simplified_lval.t) : (Simplified_lval.t*offset) list =
  let rec list_of_offset (o: offset) : (offset*offset) list =
    match o with
      NoOffset -> [NoOffset,o]
    | Index(e,ofs) ->
      let li =
        List.map
          (fun (o1,o2) -> (Index(e,o1),o2))
          (list_of_offset ofs)
      in
      (NoOffset,o)::li
    | Field(f, ofs) ->
      let li =
        List.map
          (fun (o1,o2) -> (Field(f,o1),o2))
          (list_of_offset ofs)
      in
      (NoOffset,o)::li
  in
  let lv, off = Simplified_lval.removeOffsetLval lv1 in
  List.map
    (fun (o1,o2) -> (Simplified_lval.addOffsetLval o1 lv,o2))
    (list_of_offset off)

