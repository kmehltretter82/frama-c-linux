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

module Simplified_lval =
struct
  include Lval

  let nul_exp=
    let loc = Location.unknown in
    Cil.zero ~loc

  exception IsExp of exp
  
  let rec simplify_lval (h,o) =
    (simplify_host h, simplify_offset o)
    
  and simplify_host h =
    match h with
      Var _ -> h
    | Mem e -> Mem (simplify_exp e)
                 
  and simplify_offset o =
    match o with
      NoOffset -> NoOffset
    | Field(f,o) -> Field(f, simplify_offset o)
    | Index(_e,o) -> Index(nul_exp, simplify_offset o)

  and simplify_exp e =
    try
      let simplified_enode =
        match e.enode with
        | Lval lv -> Lval (simplify_lval lv)
        | AddrOf lv -> AddrOf (simplify_lval lv)
        | StartOf lv -> StartOf (simplify_lval lv)
        | BinOp(PlusPI,e1,_,t) | BinOp(MinusPI,e1,_,t) -> BinOp(PlusPI,simplify_exp e1,nul_exp,t)
        | CastE(_,e) -> raise (IsExp (simplify_exp e))
        | _ -> raise (IsExp nul_exp)                            
      in
      {e with enode=simplified_enode}
    with
    IsExp e -> e
end
  

(* module Simplified_exp =
 * struct
 *   type simplified_exp =
 *       BNone (\* anything that is not a lval or an adress *\)
 *     | BLVal of lval (\* a simplified lval*\)
 *     | BAddrOf of lval
 * 
 * 
 * 
 *   
 * end *)
