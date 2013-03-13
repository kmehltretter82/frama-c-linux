(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2013                                               *)
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

let t_torig_ref =
  ref 
    { torig_name = "";
      tname = "";
      ttype = TVoid [];
      treferenced = false }

let set_t ty = t_torig_ref := ty

let is_now_referenced () = !t_torig_ref.treferenced <- true

let t () = TNamed(!t_torig_ref, [])
let is_t ty = Cil_datatype.Typ.equal ty (t ())

let apply_on_var ?loc funname e = Misc.mk_call ?loc ("__gmpz_" ^ funname) [ e ]
let init ?loc e = apply_on_var "init" ?loc e
let clear ?loc e = apply_on_var "clear" ? loc e

let get_set_suffix_and_arg e = 
  let ty = Cil.typeOf e in
  if is_t ty then "", [ e ]
  else
    match Cil.unrollType ty with
    | TInt(IChar, _) -> 
      (if Cil.theMachine.Cil.theMachine.char_is_unsigned then "_ui" 
       else "_si"), 
      [ e ]
    | TInt((IBool | IUChar | IUInt | IUShort | IULong), _) ->
      "_ui", [ e ]
    | TInt((ISChar | IShort | IInt | ILong), _) -> "_si", [ e ]
    | TInt((ILongLong | IULongLong), _) -> assert false
    | TPtr(TInt(IChar, _), _) ->
      "_str",
	(* decimal base for the number given as string *)
      [ e; Cil.integer ~loc:Location.unknown 10 ]
    | _ -> assert false

let generic_affect ?loc fname lv ev e =
  let ty = Cil.typeOf ev in
  if is_t ty then 
    let suf, args = get_set_suffix_and_arg e in
    Misc.mk_call ?loc (fname ^ suf) (ev :: args)
  else
    Cil.mkStmtOneInstr ~valid_sid:true (Set(lv, e, Location.unknown))

let init_set ?loc lv ev e = generic_affect ?loc "__gmpz_init_set" lv ev e
let affect ?loc lv ev e = generic_affect ?loc "__gmpz_set" lv ev e

(*
Local Variables:
compile-command: "make"
End:
*)
