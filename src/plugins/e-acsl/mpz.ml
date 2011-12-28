(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012                                                    *)
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
open Cil

let t_torig =
  { torig_name = "mpz_t";
    tname = "mpz_t";
    ttype = TVoid [] (* incorrect but does not matter *);
    treferenced = false }

let is_now_referenced () = t_torig.treferenced <- true

let t = TNamed(t_torig, [])
let is_t ty = Cil_datatype.Typ.equal ty t

let apply_on_var funname e = Misc.mk_call ("__gmpz_" ^ funname) [ e ]
let init = apply_on_var "init"
let clear = apply_on_var "clear"

let get_set_suffix_and_arg e = 
  let ty = typeOf e in
  if is_t ty then "", [ e ]
  else
    match unrollType ty with
    | TInt(IChar, _) -> 
      (if theMachine.char_is_unsigned then "_ui" else "_si"), [ e ]
    | TInt((IBool | IUChar | IUInt | IUShort | IULong), _) ->
      "_ui", [ e ]
    | TInt((ISChar | IShort | IInt | ILong), _) -> "_si", [ e ]
    | TInt((ILongLong | IULongLong), _) -> assert false
    | TPtr(TInt(IChar, _), _) ->
      "_str",
	(* decimal base for the number given as string *)
      [ e; integer ~loc:Location.unknown 10 ]
    | _ -> assert false

let generic_affect fname lv ev e =
  let ty = typeOf ev in
  if is_t ty then 
    let suf, args = get_set_suffix_and_arg e in
    Misc.mk_call (fname ^ suf) (ev :: args)
  else
    mkStmtOneInstr ~valid_sid:true (Set(lv, e, Location.unknown))

let init_set = generic_affect "__gmpz_init_set"
let affect = generic_affect "__gmpz_set"

(*
Local Variables:
compile-command: "make"
End:
*)
