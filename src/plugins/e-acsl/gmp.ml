(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2018                                               *)
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

(**************************************************************************)
(***************************** mpz type ***********************************)
(**************************************************************************)

let z_t_torig_ref =
  ref
    { torig_name = "";
      tname = "";
      ttype = TVoid [];
      treferenced = false }

let z_t_struct_torig_ref =
  ref
    { torig_name = "";
      tname = "";
      ttype = TVoid [];
      treferenced = false }

let set_z_t ty = z_t_torig_ref := ty

let is_z_now_referenced () = !z_t_torig_ref.treferenced <- true

let z_t () = TNamed(!z_t_torig_ref, [])

let z_t_ptr () = TNamed(
  {
    torig_name = "";
    tname = "__e_acsl_mpz_struct *";
    ttype = TArray(
      TNamed(!z_t_struct_torig_ref, []),
      Some (Cil.one ~loc:Cil_datatype.Location.unknown),
      {scache = Not_Computed},
      []);
    treferenced = true;
  },
[])

let is_z_t ty = Cil_datatype.Typ.equal ty (z_t ())

(**************************************************************************)
(***************************** mpq type ***********************************)
(**************************************************************************)

let q_t_torig_ref =
  ref
    { torig_name = "";
      tname = "";
      ttype = TVoid [];
      treferenced = false }

let set_q_t ty = q_t_torig_ref := ty

let is_q_now_referenced () = !q_t_torig_ref.treferenced <- true

let q_t () = TNamed(!q_t_torig_ref, [])
let is_q_t ty = Cil_datatype.Typ.equal ty (q_t ())

(**************************************************************************)
(******************* Initialization of mpz and mpq types ******************)
(**************************************************************************)

let init_t () =
  Options.feedback ~level:2 "initializing GMP types.";
  let set_mp_t = object
    inherit Cil.nopCilVisitor
    method !vglob = function
    | GType({ torig_name = s } as info, _) when s = "__e_acsl_mpz_t" ->
      set_z_t info;
      Cil.SkipChildren
    | GType({ torig_name = s } as info, _) when s = "__e_acsl_mpq_t" ->
      set_q_t info;
      Cil.SkipChildren
    | _ ->
      Cil.SkipChildren
  end in
  Cil.visitCilFileSameGlobals set_mp_t (Ast.get ())

(**************************************************************************)
(************************* Calls to builtins ******************************)
(**************************************************************************)

let apply_on_var ~loc funname e =
  let prefix =
    let ty = Cil.typeOf e in
    if is_z_t ty then "__gmpz_"
    else if is_q_t ty then "__gmpq_"
    else assert false
  in
  Misc.mk_call ~loc (prefix ^ funname) [ e ]
let init ~loc e = apply_on_var "init" ~loc e
let clear ~loc e = apply_on_var "clear" ~loc e

exception Longlong of ikind

let get_set_suffix_and_arg e =
  let ty = Cil.typeOf e in
  if is_z_t ty || is_q_t ty then "", [ e ]
  else
    match Cil.unrollType ty with
    | TInt(IChar, _) ->
      (if Cil.theMachine.Cil.theMachine.char_is_unsigned then "_ui"
       else "_si"),
      [ e ]
    | TInt((IBool | IUChar | IUInt | IUShort | IULong), _) ->
      "_ui", [ e ]
    | TInt((ISChar | IShort | IInt | ILong), _) -> "_si", [ e ]
    | TInt((ILongLong | IULongLong as ikind), _) -> raise (Longlong ikind)
    | TPtr(TInt(IChar, _), _) ->
      "_str",
      (* decimal base for the number given as string *)
      [ e; Cil.integer ~loc:e.eloc 10 ]
    | TFloat((FDouble | FFloat), _) ->
      (* FFloat is a strict subset of FDouble (modulo exceptional numbers)
        Hence, calling [set_d] for bor of them is sound.
        HOWEVER: the machdep MUST NOT be vulnerable to double rounding *)
      "_d", [ e ]
    | TFloat(FLongDouble, _) ->
      Error.not_yet "creating gmp from long double"
    | _ ->
      assert false

let generic_affect ~loc fname lv ev e =
  let ty = Cil.typeOf ev in
  if is_z_t ty then begin
    assert
      (* Missing cast/wrong typing happened previously *)
      (not (is_q_t (Cil.typeOf e)));
    let suf, args = get_set_suffix_and_arg e in
    Misc.mk_call ~loc (fname ^ suf) (ev :: args)
  end else if is_q_t ty then begin
    assert
      (* Missing cast/wrong typing happened previously *)
      (not (is_z_t (Cil.typeOf e)));
    (* TODO: If we try to factorize the following the above
      then the result is different... why ?! *)
    let suf, args = get_set_suffix_and_arg e in
    Misc.mk_call ~loc (fname ^ suf) (ev :: args)
  end else
    Cil.mkStmtOneInstr ~valid_sid:true (Set(lv, e, e.eloc))

let init_set ~loc lv ev e =
  let fname =
    let ty = Cil.typeOf ev in
    if is_z_t ty then
      "__gmpz_init_set"
    else if is_q_t ty then
      Options.fatal "no __gmpq_init_set: init then set separately"
    else
      ""
  in
  try generic_affect ~loc fname lv ev e
  with
  | Longlong IULongLong ->
    (match e.enode with
    | Lval elv ->
      assert (is_z_t (Cil.typeOf ev));
      let call = Misc.mk_call
        ~loc
        "__gmpz_import"
        [ ev;
          Cil.one ~loc;
          Cil.one ~loc;
          Cil.sizeOf ~loc (TInt(IULongLong, []));
          Cil.zero ~loc;
          Cil.zero ~loc;
          Cil.mkAddrOf ~loc elv ]
      in
      Cil.mkStmt ~valid_sid:true (Block (Cil.mkBlock [ init ~loc ev; call ]))
    | _ ->
      Error.not_yet "unsigned long long expression requiring GMP")
  | Longlong ILongLong ->
    Error.not_yet "long long requiring GMP"

let affect ~loc lv ev e =
  let fname =
    let ty = Cil.typeOf ev in
    if is_z_t ty then "__gmpz_set"
    else if is_q_t ty then "__gmpq_set"
    else ""
  in
  try generic_affect ~loc fname lv ev e
  with Longlong _ ->
    Error.not_yet "quantification over long long and requiring GMP"

(*
Local Variables:
compile-command: "make"
End:
*)
