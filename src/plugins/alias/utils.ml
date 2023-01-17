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
type basic_lval =  BNone | BLval of lval | BAddrOf of lval

(* finds, in an expression, the "basic" lval (eg a variable, a pointer or an array name). *)
let rec find_basic_lval (exp:exp) : basic_lval =
  match exp.enode with
    Lval lv -> BLval lv
  | AddrOf lv -> BAddrOf lv
  | CastE (_,exp) -> find_basic_lval exp
  | UnOp (_,exp,_) -> find_basic_lval exp
  | BinOp (_,exp1,exp2,_) ->
    begin
      match (find_basic_lval exp1, find_basic_lval exp2) with
        (BNone,BNone) -> BNone
      | (BNone, res2) -> res2
      | (res1, BNone) -> res1
      | _ -> failwith "find_basic_lval: 2 basic lval in a BinOp"
    end
  | _ -> BNone
