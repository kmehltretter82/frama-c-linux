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

let library_files () =       
  List.map
    (Options.Share.file ~error:true)
    [ "e_acsl_gmp_types.h";
      "e_acsl_gmp.h";
      "e_acsl.h";
      "memory_model/e_acsl_mmodel_api.h";
      "memory_model/e_acsl_bittree.h";
      "memory_model/e_acsl_mmodel.h" ]

(* ************************************************************************** *)
(** {2 Builders} *)
(* ************************************************************************** *)

let library_functions = Datatype.String.Hashtbl.create 17
let register_library_function vi = 
  Datatype.String.Hashtbl.add library_functions vi.vname vi

let reset () = Datatype.String.Hashtbl.clear library_functions

let mk_call ?(loc=Location.unknown) ?result fname args =
  let vi =  
    try Datatype.String.Hashtbl.find library_functions fname 
    with Not_found -> Options.fatal "unregistered library function `%s'" fname
  in
  let f = Cil.evar ~loc vi in
  vi.vreferenced <- true;
  let ty_params = match vi.vtype with
    | TFun(_, Some l, _, _) -> l
    | _ -> assert false
  in
  let args =
    List.map2
      (fun (_, ty, _) arg -> 
	match ty, unrollType (typeOf arg), arg.enode with
	| TPtr _, TArray _, Lval lv -> Cil.new_exp ~loc (StartOf lv)
	| TPtr _, TArray _, _ -> assert false
	| _, ty_arg, _ -> Cil.mkCastT ~force:false ~e:arg ~newt:ty ~oldt:ty_arg)
      ty_params
      args
  in
  mkStmtOneInstr ~valid_sid:true (Call(result, f, args, loc))

let mk_debug_mmodel_stmt stmt =
  if Options.debug_atleast 2 then
    let debug = mk_call "__debug" [] in
    Cil.mkStmt ~valid_sid:true (Block (Cil.mkBlock [ stmt; debug]))
  else 
    stmt

type annotation_kind = Assertion | Precondition | Postcondition | Invariant

let kind_to_string loc k = 
  mkString 
    ~loc
    (match k with
    | Assertion -> "Assertion"
    | Precondition -> "Precondition"
    | Postcondition -> "Postcondition"
    | Invariant -> "Invariant")

(* Build a C conditional doing a runtime assertion check. *)
let mk_e_acsl_guard ?(reverse=false) kind e p =
  let loc = p.loc in
  let msg = 
    Kernel.Unicode.without_unicode
      (Pretty_utils.sfprintf "%a@?" Cil.d_predicate_named) p 
  in
  let line = (fst loc).Lexing.pos_lnum in
  let e = if reverse then e else new_exp ~loc:e.eloc (UnOp(LNot, e, intType)) in
  mk_call 
    ~loc 
    "e_acsl_assert" 
    [ e; kind_to_string loc kind; mkString loc msg; Cil.integer loc line ] 

let result_lhost kf =
  let stmt = 
    try Kernel_function.find_return kf 
    with Kernel_function.No_Statement -> assert false
  in
  match stmt.skind with
  | Return(Some { enode = Lval (lhost, NoOffset) }, _) -> lhost
  | _ -> assert false

let result_vi kf = match result_lhost kf with
  | Var vi -> vi
  | Mem _ -> assert false

(*
Local Variables:
compile-command: "make"
End:
*)
