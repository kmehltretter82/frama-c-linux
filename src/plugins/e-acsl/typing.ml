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
open Cil

let compatible_type ty ty' = 
  (* compatible if the two type has the same "integrality" *)
  isIntegralType ty = isIntegralType ty'

(* convert [e] corresponding to a term of type [ty] in a way that it is
   compatible with the given context. *)
let context_sensitive ?loc env ctx is_mpz_string t_opt e = 
  let ty = typeOf e in
  let mk_mpz env e = 
    Env.new_var env t_opt Mpz.t (fun lv v -> [ Mpz.init_set (var lv) v e ]) 
  in
  let do_int_ctx ty' =
    let e, env = if is_mpz_string then mk_mpz env e else e, env in
    if Mpz.is_t ty || is_mpz_string then
      (* cast the mpz into a C integer *)
      let name = 
	if isSignedInteger ty' then "__gmpz_get_si" else "__gmpz_get_ui" 
      in
      Options.warning
	?source:(Extlib.opt_map fst loc)
	~once:true
	"@[missing guard for ensuring that the given integer is \
C-representable@]"; 
      Env.new_var 
	env
	None
	ty'
	(fun v _ -> [ Misc.mk_call ?loc ~result:(var v) name [ e ] ])
    else
      e, env
  in
  match ctx with
  | Ctype ty' -> do_int_ctx ty'
  | Linteger ->
    if Mpz.is_t ty then
      e, env
    else begin
      (* Convert the C integer into a mpz. 
	 Remember: very long integer constant has been temporary converted into
	 strings *)
      assert (Options.verify
		(isIntegralType ty || is_mpz_string) 
		"how to convert %a to an integer?"
		d_type ty); 
      mk_mpz env e
    end
  | ty' when Logic_const.is_boolean_type ty' -> do_int_ctx intType
  | Ltype _ | Lvar _ | Lreal | Larrow _ -> 
    (* not yet supported, thus cannot occur at this point *)
    assert false

let principal_type ty ty' = match ty, ty' with
  | Ctype ty, Ctype ty' when isIntegralType ty -> 
    assert (isIntegralType ty');
    Ctype (arithmeticConversion ty ty')
  | Ctype ty, Linteger | Linteger, Ctype ty when isIntegralType ty -> Linteger
  (* not possible to unify cases below (see caml bts #5432) *)
  | Ctype ty1, Ctype ty2 when Mpz.is_t ty1 && isIntegralType ty2 -> Linteger
  | Ctype ty2, Ctype ty1 when Mpz.is_t ty1 && isIntegralType ty2 -> Linteger
  | Ctype tty, Ctype tty' -> 
    assert (compatible_type tty tty');
    ty
  | Ctype _, Linteger | Linteger, Ctype _ -> Linteger
  | Linteger, Linteger -> Linteger
  | (Ltype _ | Lvar _ | Lreal | Larrow _), _
  | _, (Ltype _ | Lvar _ | Lreal | Larrow _) -> 
    (* not yet supported, thus cannot occur at this point *)
    Options.error "What is this %a here?" d_logic_type ty'; 
    assert false

let principal_type_from_term t1 t2 =
  let typ t = 
    let ty = t.term_type in
    if Logic_const.is_boolean_type ty then Ctype intType
    else match t.term_node, ty with
    | TConst (CInt64(_, (ILongLong | IULongLong), _)), Linteger -> 
      (* constant potentially not representable in C *)
      Linteger
    | TConst (CInt64(_, k, _)), _ -> 
      (* C-representable constant *)
      Ctype (TInt (k, []))
    | _, _ -> 
      (* for direct C terms, should be able to infer the corresponding C type *)
      ty
  in
  principal_type (typ t1) (typ t2) 

(*
Local Variables:
compile-command: "make"
End:
*)
