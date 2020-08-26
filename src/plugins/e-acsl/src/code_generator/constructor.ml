(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

(* ********************************************************************** *)
(* Expressions *)
(* ********************************************************************** *)

let mk_deref ~loc lv = Cil.new_exp ~loc (Lval(Mem(lv), NoOffset))

(* ********************************************************************** *)
(* Statements *)
(* ********************************************************************** *)

let mk_stmt sk = Cil.mkStmt ~valid_sid:true sk
let mk_instr i = mk_stmt (Instr i)
let mk_call ~loc ?result e args = mk_instr (Call(result, e, args, loc))

type annotation_kind =
  | Assertion
  | Precondition
  | Postcondition
  | Invariant
  | RTE

let kind_to_string loc k =
  Cil.mkString
    ~loc
    (match k with
     | Assertion -> "Assertion"
     | Precondition -> "Precondition"
     | Postcondition -> "Postcondition"
     | Invariant -> "Invariant"
     | RTE -> "RTE")

let mk_block stmt b = match b.bstmts with
  | [] ->
    (match stmt.skind with
     | Instr(Skip _) -> stmt
     | _ -> assert false)
  | [ s ] -> s
  |  _ :: _ -> mk_stmt (Block b)

(* ********************************************************************** *)
(* E-ACSL specific code *)
(* ********************************************************************** *)

let mk_lib_call ~loc ?result fname args =
  let vi = Misc.get_lib_fun_vi fname in
  let f = Cil.evar ~loc vi in
  vi.vreferenced <- true;
  let make_args ~variadic args param_ty =
    let rec make_rev_args res args param_ty =
      match args, param_ty with
      | arg :: args_tl, (_, ty, _) :: param_ty_tl ->
        let e =
          match ty, Cil.unrollType (Cil.typeOf arg), arg.enode with
          | TPtr _, TArray _, Lval lv -> Cil.new_exp ~loc (StartOf lv)
          | TPtr _, TArray _, _ -> assert false
          | _, _, _ -> arg
        in
        let e = Cil.mkCast ~force:false ~newt:ty ~e in
        make_rev_args (e :: res) args_tl param_ty_tl
      | arg :: args_tl, [] when variadic -> make_rev_args (arg :: res) args_tl []
      | [], [] -> res
      | _, _ ->
        Options.fatal
          "Mismatch between the number of expressions given and the number \
           of arguments in the signature when calling function '%s'"
          fname
    in
    List.rev (make_rev_args [] args param_ty)
  in
  let args = match Cil.unrollType vi.vtype with
    | TFun(_, Some params, variadic, _) -> make_args ~variadic args params
    | TFun(_, None, _, _) -> []
    | _ -> assert false
  in
  mk_call ~loc ?result f args

let mk_rtl_call ~loc ?result fname args =
  mk_lib_call ~loc ?result (Functions.RTL.mk_api_name fname) args

(* ************************************************************************** *)
(** {2 Handling the E-ACSL's C-libraries, part II} *)
(* ************************************************************************** *)

let mk_full_init_stmt vi =
  let loc = vi.vdecl in
  mk_rtl_call ~loc "full_init" [ Cil.evar ~loc vi ]

let mk_initialize ~loc (host, offset as lv) = match host, offset with
  | Var _, NoOffset ->
    mk_rtl_call ~loc "full_init" [ Cil.mkAddrOf ~loc lv ]
  | _ ->
    let typ = Cil.typeOfLval lv in
    mk_rtl_call ~loc
      "initialize"
      [ Cil.mkAddrOf ~loc lv; Cil.new_exp loc (SizeOf typ) ]

let mk_named_store_stmt name ?str_size vi =
  let ty = Cil.unrollType vi.vtype in
  let loc = vi.vdecl in
  let store = mk_rtl_call ~loc name in
  match ty, str_size with
  | TArray(_, Some _,_,_), None ->
    store [ Cil.evar ~loc vi; Cil.sizeOf ~loc ty ]
  | TPtr(TInt(IChar, _), _), Some size ->
    store [ Cil.evar ~loc vi ; size ]
  | TPtr _, Some size ->
    (* a VLA that has been converted into a pointer by the kernel *)
    store [ Cil.evar ~loc vi; size ]
  | _, None ->
    store [ Cil.mkAddrOfVi vi ; Cil.sizeOf ~loc ty ]
  | _, Some size ->
    Options.fatal
      "unexpected types for arguments of function '%s': \
       %s got type %a, while representing a memory block of %a bytes"
      name
      vi.vname
      Printer.pp_typ ty
      Printer.pp_exp size

let mk_store_stmt ?str_size vi =
  mk_named_store_stmt "store_block" ?str_size vi

let mk_duplicate_store_stmt ?str_size vi =
  mk_named_store_stmt "store_block_duplicate" ?str_size vi

let mk_delete_stmt ?(is_addr=false) vi =
  let loc = vi.vdecl in
  let mk = mk_rtl_call ~loc "delete_block" in
  match is_addr, Cil.unrollType vi.vtype with
  | _, TArray(_, Some _, _, _) | true, _ -> mk [ Cil.evar ~loc vi ]
  | _ -> mk [ Cil.mkAddrOfVi vi ]

let mk_mark_readonly vi =
  let loc = vi.vdecl in
  mk_rtl_call ~loc "mark_readonly" [ Cil.evar ~loc vi ]

let mk_runtime_check_with_msg ~loc msg kind kf e =
  let file = (fst loc).Filepath.pos_path in
  let line = (fst loc).Filepath.pos_lnum in
  mk_rtl_call ~loc
    "assert"
    [ e;
      kind_to_string loc kind;
      Cil.mkString ~loc (Functions.RTL.get_original_name kf);
      Cil.mkString ~loc msg;
      Cil.mkString ~loc (Filepath.Normalized.to_pretty_string file);
      Cil.integer loc line ]

let mk_runtime_check kind kf e p =
  let loc = p.pred_loc in
  let msg =
    Kernel.Unicode.without_unicode
      (Format.asprintf "%a@?" Printer.pp_predicate) p
  in
  mk_runtime_check_with_msg ~loc msg kind kf e

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
