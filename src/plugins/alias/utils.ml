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

(* type of the return of the following function *)
type basic_lval =  BNone | BLval of lval | BAddrOf of lval | BIndex of basic_lval * exp

(* finds, in an expression, the "basic" lval (eg a variable, a pointer or an array name). *)
let rec find_basic_lval (exp:exp) : basic_lval =
  match exp.enode with
    Lval lv -> BLval lv
  | AddrOf lv -> BAddrOf lv
  | StartOf lv -> BAddrOf lv
  | CastE _ -> find_basic_lval (Cil.stripCasts exp)
  | UnOp (_,exp,_) -> find_basic_lval exp
  | BinOp (PlusPI,exp1,exp2,_) -> BIndex (find_basic_lval exp1,exp2)
  | BinOp (_,exp1,exp2,_) ->
    begin
      match (find_basic_lval exp1, find_basic_lval exp2) with
        (BNone,BNone) -> BNone
      | (BNone, res2) -> res2
      | (res1, BNone) -> res1
      | _ -> failwith "find_basic_lval: 2 basic lval in a BinOp"
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
