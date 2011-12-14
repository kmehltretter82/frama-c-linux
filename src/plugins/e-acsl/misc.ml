(**************************************************************************)
(*                                                                        *)
(*  This file is part of the E-ACSL plug-in of Frama-C.                   *)
(*                                                                        *)
(*  Copyright (C) 2011                                                    *)
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

(* ************************************************************************** *)
(** {2 Builders} *)
(* ************************************************************************** *)

let e_acsl_header () = GText (Read_header.text ())

let new_lval ?(loc=Location.unknown) v = new_exp ~loc (Lval (var v))

let mk_call ?(loc=Location.unknown) ?result fname args =
  (* the type is incorrect, but it doesn't matter *)
  (* [JS 2011/04/12] should not generate a new variable by function name *) 
  (* [TODO] require a projectified table to associate an lval to each name *)
  let ty = TFun(voidType, None, false, []) in
  let f = new_lval ~loc (makeGlobalVar fname ty) in
  mkStmt ~valid_sid:true (Instr(Call(result, f, args, loc)))

(* Build a C conditional doing a runtime assertion check. *)
let mk_e_acsl_guard ?(reverse=false) e p =
  let loc = p.loc in
  let unicode = Kernel.Unicode.get () in
  Kernel.Unicode.off ();
  let msg = Pretty_utils.sfprintf "%a@?" Cil.d_predicate_named p in
  Kernel.Unicode.set unicode;
  let s = mk_call ~loc "e_acsl_fail" [ mkString loc msg ] in
  let e = if reverse then new_exp ~loc:e.eloc (UnOp(LNot, e, intType)) else e in
  mkStmt ~valid_sid:true (If(e, mkBlock [ s ], mkBlock [], loc))

(*
Local Variables:
compile-command: "make"
End:
*)
