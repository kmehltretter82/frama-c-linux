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

let is_representable _n k _s = match k with
  | IBool | IChar | IUChar | IUInt | IUShort | IULong | ISChar | IShort | IInt
  | ILong ->
    true
  | ILongLong | IULongLong ->
    false

(******************************************************************************)
(* NEW TYPE SYSTEM *)
(******************************************************************************)

open Cil_datatype

module BI = My_bigint

type eacsl_typ =
  | Interv of BI.t * BI.t
  | Z
  | No_integral(* of logic_type*)

let typ_of_eacsl_typ = function
  | Interv(l, u) -> 
    let is_pos = BI.ge l BI.zero in
    (try 
       let mk k = TInt(k, []) in
       let ty_l = mk (intKindForValue l is_pos) in
       let ty_u = mk (intKindForValue u is_pos) in
       arithmeticConversion ty_l ty_u
     with Not_found -> 
       Mpz.t)
  | Z -> Mpz.t
  | No_integral(* _*) -> assert false

let eacsl_typ_of_typ = function
  | TInt(k, _) as ty -> 
    let n = bitsSizeOf ty in
    let l, u = 
      if isSigned k then min_signed_number n, max_signed_number n
      else BI.zero, max_unsigned_number n
    in
    Interv(l, u)      
  | _ -> No_integral

exception Cannot_compare
let meet ty1 ty2 = match ty1, ty2 with
  | Interv(l1, u1), Interv(l2, u2) -> Interv(BI.max l1 l2, BI.min u1 u2)
  | Interv _, Z -> ty1
  | Z, Interv _ -> ty2
  | Z, Z -> Z
  | No_integral, No_integral -> No_integral
  | (Z | Interv _), No_integral
  | No_integral, (Z | Interv _) -> raise Cannot_compare

let join ty1 ty2 = match ty1, ty2 with
  | Interv(l1, u1), Interv(l2, u2) -> Interv(BI.min l1 l2, BI.max u1 u2)
  | Interv _, Z | Z, Interv _ | Z, Z -> Z
  | No_integral, No_integral -> No_integral
  | (Z | Interv _), No_integral
  | No_integral, (Z | Interv _) -> raise Cannot_compare

module Global_env: sig 
  val get: term -> typ
  val add: term -> eacsl_typ -> unit
  val clear: unit -> unit
end = struct

  module H = Hashtbl.Make
    (struct
      type t = term
      let equal (t1:term) t2 = t1 == t2
      let hash = Term.hash
     end)

  let tbl = H.create 17

  let clear () = H.clear tbl
  let get t = try H.find tbl t with Not_found -> assert false

  let add t typ = 
    assert (not (H.mem tbl t));
    H.add tbl t (typ_of_eacsl_typ typ)

end

let typ_of_term = Global_env.get

let int_to_interv n = 
  let b = BI.of_int n in
  Interv (b, b)

let rec type_constant = function
  | CInt64(n, _, _) -> Interv(n, n)
  | CChr c -> type_constant (charConstToInt c)
  | CStr _ | CWStr _ | CReal _ | CEnum _ -> No_integral 

let size_of ty =
  try int_to_interv (sizeOf_int ty)
  with SizeOfError _ -> eacsl_typ_of_typ ulongLongType

let align_of ty = int_to_interv (alignOf_int ty)

let rec type_term env t = 
  let ty = match t.term_node with
    | TConst c -> type_constant c
    | TLval lv -> type_term_lval env t.term_type lv
    | TSizeOf ty -> size_of ty
    | TSizeOfE t -> 
      ignore (type_term env t);
      let ty = match t.term_type with
	| Ctype ty -> ty
	| _ -> assert false
      in
      size_of ty
    | TSizeOfStr s -> int_to_interv (String.length s + 1 (* '\0' *)) 
    | TAlignOf ty -> align_of ty
    | TAlignOfE t ->
      ignore (type_term env t);
      let ty = match t.term_type with
	| Ctype ty -> ty
	| _ -> assert false
      in
      align_of ty
    | TUnOp(Neg, t) -> 
      unary_arithmetic
	(fun l u -> let opp = BI.sub BI.zero in opp u, opp l) env t
    | TUnOp(BNot, _) -> Error.not_yet "missing unary bitwise operator"
    | TUnOp(LNot, t) ->
      ignore (type_term env t);
      Interv(BI.zero, BI.one)
    | TBinOp(PlusA, t1, t2) -> 
      let add l1 u1 l2 u2 = BI.add l1 l2, BI.add u1 u2 in
      binary_arithmetic add env t1 t2
    | TBinOp((PlusPI | IndexPI | MinusPI | MinusPP), t1, t2) -> 
      ignore (type_term env t1);
      ignore (type_term env t2);
      No_integral
    | TBinOp(MinusA, t1, t2) -> 
      let sub l1 u1 l2 u2 = BI.sub l1 u2, BI.sub u1 l2 in
      binary_arithmetic sub env t1 t2
    | TBinOp(Mult, t1, t2) -> 
      let mul l1 u1 l2 u2 = 
	(* probably not the most efficient, but the shortest *)
	let a = BI.mul l1 l2 in
	let b = BI.mul l1 u2 in
	let c = BI.mul u1 l2 in
	let d = BI.mul u1 u2 in
	BI.min a (BI.min b (BI.min c d)), BI.max a (BI.max b (BI.max c d))
      in
      binary_arithmetic mul env t1 t2
    | TBinOp(Div, t1, t2) -> 
      let div l1 u1 l2 u2 = 
	(* probably not the most efficient, but the shortest *)
	let a = BI.div l1 l2 in
	let b = BI.div l1 u2 in
	let c = BI.div u1 l2 in
	let d = BI.div u1 u2 in
	BI.min a (BI.min b (BI.min c d)), BI.max a (BI.max b (BI.max c d))
      in
      binary_arithmetic div env t1 t2
    | TBinOp(Mod, _t1, _t2) -> 
      Error.not_yet "modulo"
    | TBinOp(Shiftlt, _t1, _t2) | TBinOp(Shiftrt, _t1, _t2) ->
      Error.not_yet "left/right shift"
    | TBinOp((Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr), t1, t2) -> 
      ignore (type_term env t1);
      ignore (type_term env t2);
      Interv(BI.zero, BI.one)
    | TBinOp((BAnd | BXor | BOr), _t1, _t2) -> 
      Error.not_yet "missing binary bitwise operator"
    | TCastE(ty, t) -> 
      let ty_t = type_term env t in
      let ty_c = eacsl_typ_of_typ ty in
      (try meet ty_c ty_t with Cannot_compare -> ty_c)
    | TAddrOf _ | TStartOf _ -> No_integral
    | Tapp _ -> Error.not_yet "applying logic function"
    | Tlambda _ -> Error.not_yet "functional"
    | TDataCons _ -> Error.not_yet "constructor"
    | Tif(t1, t2, t3) -> 
      ignore (type_term env t1);
      let ty2 = type_term env t2 in
      let ty3 = type_term env t3 in
      (try join ty2 ty3 with Cannot_compare -> assert false)
    | Tat(t, _) -> type_term env t
    | Tbase_addr _ -> Error.not_yet "\\base_addr"
    | Tblock_length _ -> Error.not_yet "\\block_length"
    | Tnull -> int_to_interv 0
    | TCoerce _ -> Error.not_yet "coercion" (* Jessie specific *)
    | TCoerceE _ -> Error.not_yet "expression coercion" (* Jessie specific *)
    | TUpdate _ -> Error.not_yet "functional update"
    | Ttypeof _ -> Error.not_yet "typeof"
    | Ttype _ -> Error.not_yet "C type"
    | Tempty_set -> Error.not_yet "empty tset"
    | Tunion _ -> Error.not_yet "union of tsets"
    | Tinter _ -> Error.not_yet "intersection of tsets"
    | Tcomprehension _ -> Error.not_yet "tset comprehension"
    | Trange _ -> Error.not_yet "range"
    | Tlet _ -> Error.not_yet "let binding"
  in
  Global_env.add t ty;
  ty

and type_term_lval env ty (h, o) =
  type_term_offset env o;
  type_term_lhost env ty h

and type_term_lhost env lty = function
  | TVar lv -> (try Logic_var.Map.find lv env with Not_found -> assert false)
  | TResult ty -> eacsl_typ_of_typ ty
  | TMem t -> 
    ignore (type_term env t);
    match lty with 
    | Ctype ty -> eacsl_typ_of_typ ty
    | Linteger -> Z
    | Ltype _ | Lvar _ | Lreal | Larrow _ -> No_integral

and type_term_offset env = function
  | TNoOffset -> ()
  | TField(_, o) -> type_term_offset env o
  | TIndex(t, o) ->
    ignore (type_term env t);
    type_term_offset env o

and unary_arithmetic op env t = 
  let ty = type_term env t in
  match ty with
  | Interv(l, u) -> 
    let l, u = op l u in
    Interv (l, u)
  | Z -> Z
  | No_integral -> assert false

and binary_arithmetic op env t1 t2 =
  let ty1 = type_term env t1 in
  let ty2 = type_term env t2 in
  match ty1, ty2 with
  | Interv(l1, u1), Interv(l2, u2) -> 
    let l, u = op l1 u1 l2 u2 in
    Interv (l, u)
  | No_integral, _ | _, No_integral -> assert false
  | _, Z | Z, _ -> Z

let compute_quantif_guards_ref
    : (predicate named -> logic_var list -> predicate named -> 
       (term * relation * logic_var * relation * term) list) ref
    = Extlib.mk_fun "compute_quantif_guards_ref"

let rec type_predicate_named env p = match p.content with
  | Pfalse | Ptrue -> ()
  | Papp _ -> Error.not_yet "logic function application"
  | Pseparated _ -> Error.not_yet "separated"
  | Prel(_, t1, t2) -> 
    ignore (type_term env t1);
    ignore (type_term env t2)
  | Pand(p1, p2) | Por(p1, p2) | Pxor(p1, p2) | Pimplies(p1, p2) 
  | Piff(p1, p2) ->
    type_predicate_named env p1;
    type_predicate_named env p2
  | Pnot p -> type_predicate_named env p
  | Pif(t, p1, p2) -> 
    ignore (type_term env t);
    type_predicate_named env p1;
    type_predicate_named env p2
  | Plet _ -> Error.not_yet "let _ = _ in _"
  | Pforall(bounded_vars, { content = Pimplies(hyps, goal) })
  | Pexists(bounded_vars, { content = Pimplies(hyps, goal) }) ->
    type_predicate_named env hyps;
    let env =
      List.fold_left
	(fun _env (t1, r1, x, r2, t2) -> 
	  let ty1 = type_term env t1 in
	  let ty1 = match ty1, r1 with
	    | Interv(l, u), Rlt -> Interv(BI.add l BI.one, BI.add u BI.one)
	    | Interv(l, u), Rle -> Interv(l, u)
	    | Z, (Rlt | Rle) -> Z
	    | _, _ -> assert false
	  in
	  let ty2 = type_term env t2 in
	  (* add one here, since we increment the loop counter one more time
	     before going out the loop. *)
	  let ty2 = match ty2, r2 with
	    | Interv(l, u), Rlt -> Interv(l, u)
	    | Interv(l, u), Rle -> Interv(BI.add l BI.one, BI.add u BI.one)
	    | Z, (Rlt | Rle) -> Z
	    | _, _ -> assert false
	  in
	  Logic_var.Map.add x (join ty1 ty2) env)
	env
	(!compute_quantif_guards_ref p bounded_vars hyps)
    in
    type_predicate_named env goal
  | Pforall _ -> Error.not_yet "unguarded \\forall quantification"
  | Pexists _ -> Error.not_yet "unguarded \\exists quantification"
  | Pat(p, _) -> type_predicate_named env p
  | Pvalid _ ->  Error.not_yet "\\valid"
  | Pvalid_index _ -> Error.not_yet "\\valid_index"
  | Pvalid_range _ -> Error.not_yet "\\valid_range"
  | Pfresh _ -> Error.not_yet "\\fresh"
  | Psubtype _ -> Error.not_yet "subtyping relation" (* Jessie specific *)
  | Pinitialized _ -> Error.not_yet "\\initialized"

let type_id_predicate env p = 
  type_predicate_named
    env
    { name = []; loc = Location.unknown; content = p.ip_content }

let type_predicate p = 
  Global_env.clear ();
  type_id_predicate Logic_var.Map.empty p

(*
Local Variables:
compile-command: "make"
End:
*)
