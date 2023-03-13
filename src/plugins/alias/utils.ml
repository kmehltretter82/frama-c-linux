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

module VSet = Datatype.Int.Set
module VMap = Datatype.Int.Map

module LSet = Lval.Set
module LMap = Lval.Map


(* type of the return of the following function *)
type basic_lval =  BNone | BLval of lval | BAddrOf of lval | BIndex of basic_lval * exp

(* type of the result of the BinOp that raise this exception *)
exception Double_lval of basic_lval * basic_lval * typ

(* finds, in an expression, the "basic" lval (eg a variable, a pointer or an array name). *)
let rec find_basic_lval (exp:exp) : basic_lval =
  match exp.enode with
    Lval lv -> BLval lv
  | AddrOf lv -> BAddrOf lv
  | StartOf lv -> BAddrOf lv
  | CastE _ -> find_basic_lval (Cil.stripCasts exp)
  | UnOp (_,exp,_) -> find_basic_lval exp
  | BinOp (PlusPI,exp1,exp2,_) | BinOp(MinusPI ,exp1,exp2,_) -> BIndex (find_basic_lval exp1,exp2)
  | BinOp (_,exp1,exp2,t) ->
    begin
      let e1 = find_basic_lval exp1
      and e2 = find_basic_lval exp2
      in
      match (e1, e2) with
        (BNone,BNone) -> BNone
      | (BNone, res2) -> res2
      | (res1, BNone) -> res1
      | _ -> raise (Double_lval (e1,e2,t))
    end
  | _ -> BNone


let rec convert_bindex (blv: basic_lval) : lval =
  match blv with
    BNone -> failwith "problem here"
  | BLval lv -> lv
  | BAddrOf _ -> failwith "this should not be allowed"
  | BIndex (blv1, exp) ->
    let lv1 = convert_bindex blv1 in
    let lv1,off1 = Cil.removeOffsetLval lv1 in
    let lv2 = Cil.addOffsetLval (Index(exp,off1)) lv1 in
    lv2

let convert_blval (blv: basic_lval) : basic_lval =
  match blv with
    BIndex _ -> BLval (convert_bindex blv)
  | _ -> blv

let decompose_lval (lv1: lval) : (lval*offset) list =
  let rec list_of_offset (o: offset) : (offset*offset) list =
    match o with
      NoOffset -> [NoOffset,NoOffset]
    | Index(e,ofs) ->
      let li =
        List.map
          (fun (o1,o2) -> (Index(e,o1),o2))
          (list_of_offset ofs)
      in
      (NoOffset,ofs)::li
    | Field(f, ofs) ->
      let li =
        List.map
          (fun (o1,o2) -> (Field(f,o1),o2))
          (list_of_offset ofs)
      in
      (NoOffset,ofs)::li
  in
  let lv, off = Cil.removeOffsetLval lv1 in
  List.map
    (fun (o1,o2) -> (Cil.addOffsetLval o1 lv,o2))
    (list_of_offset off)

(* (\* returns the list of prefixes of lv1 that belong to ls *\)
 * let prefix_in_set (lv1:lval) (ls:LSet.t) : (lval*offset) list =
 *   let li = decompose_lval lv1 in
 *   List.filter (fun (lv,_) ->LSet.mem lv ls) li *)




(* [first_index a] returns a[0] *)
let first_index (lv:lval) : lval =
  let loc = Location.unknown in
  Cil.addOffsetLval (Index (Cil.zero ~loc, NoOffset)) lv

(* returns true if the index is OK (no needs to collapse) *)
let rec normalize_index (e:exp) : exp * bool =
  match e.enode with
    Const _ -> e, true
  | CastE _ -> normalize_index (Cil.stripCasts e)
  | _ -> e, false


let is_scalar_type (t:typ) =
  match Cil.unrollType t with
    TFloat _ | TInt _ -> true
  (* | TNamed (t,_) -> is_scalar t.ttype *)
  | _ -> false
