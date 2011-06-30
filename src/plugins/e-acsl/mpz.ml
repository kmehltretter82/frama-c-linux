(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2010                                               *)
(*    CEA (Commissariat à l'Énergie Atomique)                             *)
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

let apply_on_var funname e = Misc.mk_call ("mpz_" ^ funname) [ e ]
let init = apply_on_var "init"
let clear = apply_on_var "clear"

let init_set v e =
  let fname, args = match typeOf e with
    | TInt((IBool | IChar | IUChar | IUInt | IUShort | IULong), _) ->
      "ui", [ e ]
    | TInt((ISChar | IShort | IInt | ILong), _) -> "si", [ e ]
    | TInt((ILongLong | IULongLong), _) -> assert false
    | TPtr(TInt(IChar, _), _) ->
      "str",
	(* decimal base for the number given as string *)
      [ e; integer ~loc:Location.unknown 10 ]
    | _ -> assert false
  in
  Misc.mk_call ("mpz_init_set_" ^ fname) (v :: args)

(*
Local Variables:
compile-command: "make"
End:
*)
