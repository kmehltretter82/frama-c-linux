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
open Cil_datatype

module BI = My_bigint

let is_representable n _k _s = BI.ge n BI.min_int64 && BI.le n BI.max_int64

(******************************************************************************)
(** Type Lattice *)
(******************************************************************************)

type eacsl_typ =
  | Interv of BI.t * BI.t
  | Z
  | No_integral of logic_type

exception Not_representable
let typ_of_eacsl_typ = function
  | Interv(l, u) -> 
    let is_pos = BI.ge l BI.zero in
    (try 
       let mk n k = 
	 if true || is_representable n k false then TInt(k, []) 
	 else raise Not_representable
       in
       let ty_l = mk l (intKindForValue l is_pos) in
       let ty_u = mk u (intKindForValue u is_pos) in
       arithmeticConversion ty_l ty_u
     with Not_found | Not_representable -> 
       Mpz.t)
  | Z -> Mpz.t
  | No_integral (Ctype ty) -> ty
  | No_integral (Ltype _) -> Error.not_yet "typing of user-defined logic type"
  | No_integral (Lvar _) -> Error.not_yet "type variable"
  | No_integral Linteger -> assert false
  | No_integral Lreal -> Error.not_yet "real numbers"
  | No_integral (Larrow _) -> Error.not_yet "functional type"

let eacsl_typ_of_typ ty = match unrollType ty with
  | TInt(k, _) as ty -> 
    let n = bitsSizeOf ty in
    let l, u = 
      if isSigned k then min_signed_number n, max_signed_number n
      else BI.zero, max_unsigned_number n
    in
    Interv(l, u)      
  | ty -> No_integral (Ctype ty)

exception Cannot_compare
let meet ty1 ty2 = match ty1, ty2 with
  | Interv(l1, u1), Interv(l2, u2) -> 
    let l = BI.max l1 l2 in
    let u = BI.min u1 u2 in
    if BI.gt l u then raise Cannot_compare;
    Interv(l, u)
  | Interv _, Z -> ty1
  | Z, Interv _ -> ty2
  | Z, Z -> Z
  | No_integral t1, No_integral t2 when Logic_type.equal t1 t2 -> ty1
  | No_integral _, No_integral _
  | (Z | Interv _), No_integral _
  | No_integral _, (Z | Interv _) -> raise Cannot_compare

let join ty1 ty2 = match ty1, ty2 with
  | Interv(l1, u1), Interv(l2, u2) -> Interv(BI.min l1 l2, BI.max u1 u2)
  | Interv _, Z | Z, Interv _ | Z, Z -> Z
  | No_integral t1, No_integral t2 when Logic_type.equal t1 t2 -> ty1
  | No_integral _, No_integral _
  | (Z | Interv _), No_integral _
  | No_integral _, (Z | Interv _) -> raise Cannot_compare

let int_to_interv n = 
  let b = BI.of_int n in
  Interv (b, b)

(******************************************************************************)
(** Environments *)
(******************************************************************************)

module Make_env(X: sig type t val hash: t -> int end): sig 
  val add: X.t -> eacsl_typ -> unit
  val find: X.t -> eacsl_typ
  val mem: X.t -> bool
  val clear: unit -> unit
end = struct

  module H = Hashtbl.Make(struct include X let equal (t1:X.t) t2 = t1 == t2 end)
  let tbl = H.create 17
  let add = H.replace tbl
  let find = H.find tbl
  let mem = H.mem tbl
  let clear () = H.clear tbl

end

module Term_env = Make_env(Term)
module Logic_var_env = Make_env(Logic_var)

let typ_of_term t = 
  try 
    let ty = Term_env.find t in
    typ_of_eacsl_typ ty
  with Not_found -> Options.fatal "untyped term %a" Term.pretty t

let unsafe_set_term t ty =
  assert (not (Term_env.mem t));
  Term_env.add t (eacsl_typ_of_typ ty)

let clear () = 
  Term_env.clear (); 
  Logic_var_env.clear ()

(******************************************************************************)
(** Typing rules *)
(******************************************************************************)

let rec type_constant ty = function
  | CInt64(n, _, _) -> Interv(n, n)
  | CChr c -> type_constant ty (charConstToInt c)
  | CStr _ | CWStr _ | CReal _ | CEnum _ -> No_integral ty

let size_of ty =
  try int_to_interv (sizeOf_int ty)
  with SizeOfError _ -> eacsl_typ_of_typ ulongLongType

let align_of ty = int_to_interv (alignOf_int ty)

let rec type_term t = 
  let lty = t.term_type in
  let get_cty t = match t.term_type with Ctype ty -> ty | _ -> assert false in
  let ty = match t.term_node with
    | TConst c -> type_constant lty c
    | TLval lv -> type_term_lval lv
    | TSizeOf ty -> size_of ty
    | TSizeOfE t -> 
      ignore (type_term t);
      size_of (get_cty t)
    | TSizeOfStr s -> int_to_interv (String.length s + 1 (* '\0' *)) 
    | TAlignOf ty -> align_of ty
    | TAlignOfE t ->
      ignore (type_term t);
      align_of (get_cty t)
    | TUnOp(Neg, t) -> 
      unary_arithmetic
	(fun l u -> let opp = BI.sub BI.zero in opp u, opp l) t
    | TUnOp(BNot, t) ->
      unary_arithmetic
	(fun l u -> 
	  let nl = BI.lognot l in
	  let nu = BI.lognot u in
	  BI.min nl nu, BI.max nl nu) 
	t
    | TUnOp(LNot, t) ->
      ignore (type_term t);
      Interv(BI.zero, BI.one)
    | TBinOp(PlusA, t1, t2) -> 
      let add l1 u1 l2 u2 = BI.add l1 l2, BI.add u1 u2 in
      binary_arithmetic add t1 t2
    | TBinOp((PlusPI | IndexPI | MinusPI | MinusPP), t1, t2) -> 
      ignore (type_term t1);
      ignore (type_term t2);
      No_integral lty
    | TBinOp(MinusA, t1, t2) -> 
      let sub l1 u1 l2 u2 = BI.sub l1 u2, BI.sub u1 l2 in
      binary_arithmetic sub t1 t2
    | TBinOp(Mult, t1, t2) -> signed_rule BI.mul t1 t2
    | TBinOp(Div, t1, t2) -> 
      let div a b = 
	try BI.c_div a b 
	with Division_by_zero -> 
	    (* either the generated code will be dead (e.g. [false && 1/0])
	       or it contains a potential RTE and thus it is actually equivalent
	       to dead code. In any case, any type is correct at this point and
	       we generate the less restrictive one (0 is always representable)
	       in order to be as more precise as possible. *)
	    BI.zero
      in
      signed_rule div t1 t2
    | TBinOp(Mod, t1, t2) -> 
      let modu a b =
	try BI.c_rem a b with Division_by_zero -> BI.zero (* see Div *)
      in
      signed_rule modu t1 t2
    | TBinOp(Shiftlt, _t1, _t2) | TBinOp(Shiftrt, _t1, _t2) ->
      Error.not_yet "left/right shift"
    | TBinOp((Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr), t1, t2) -> 
      ignore (type_term t1);
      ignore (type_term t2);
      Interv(BI.zero, BI.one)
    | TBinOp((BAnd | BXor | BOr), _t1, _t2) -> 
      Error.not_yet "missing binary bitwise operator"
    | TCastE(ty, t) -> 
      let ty_t = type_term t in
      let ty_c = eacsl_typ_of_typ ty in
      (try meet ty_c ty_t with Cannot_compare -> ty_c)
    | TAddrOf lv | TStartOf lv -> 
      ignore (type_term_lval lv);
      No_integral lty
    | Tapp _ -> Error.not_yet "applying logic function"
    | Tlambda _ -> Error.not_yet "functional"
    | TDataCons _ -> Error.not_yet "constructor"
    | Tif(t1, t2, t3) -> 
      ignore (type_term t1);
      let ty2 = type_term t2 in
      let ty3 = type_term t3 in
      (try join ty2 ty3 with Cannot_compare -> assert false)
    | Tat(t, _) -> type_term t
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
  Term_env.add t ty;
  ty

and type_term_lval (h, o) =
  type_term_offset o;
  type_term_lhost h

and type_term_lhost = function
  | TVar lv -> 
    (try Logic_var_env.find lv 
     with Not_found -> 
       (* C variable *)
       (*       match lty with*) (* don't work yet: see bts #1064 *)
       match lv.lv_type with
       | Ctype ty -> eacsl_typ_of_typ ty
       | _ -> 
	 Options.fatal "invalid type for logic var %a: %a" 
	   Logic_var.pretty lv Logic_type.pretty lv.lv_type)
  | TResult ty -> eacsl_typ_of_typ ty
  | TMem t -> 
    let ty = type_term t in
    (* got a pointer *)
    match ty with
    | No_integral (Ctype (TPtr(ty, _) | TArray(ty, _, _, _))) ->
      eacsl_typ_of_typ ty
    | No_integral _ | Z | Interv _ -> assert false

and type_term_offset = function
  | TNoOffset -> ()
  | TField(_, o) -> type_term_offset o
  | TIndex(t, o) ->
    ignore (type_term t);
    type_term_offset o

and unary_arithmetic op t = 
  let ty = type_term t in
  match ty with
  | Interv(l, u) -> 
    let l, u = op l u in
    Interv (l, u)
  | Z -> Z
  | No_integral _ -> assert false

and binary_arithmetic op t1 t2 =
  let ty1 = type_term t1 in
  let ty2 = type_term t2 in
  match ty1, ty2 with
  | Interv(l1, u1), Interv(l2, u2) -> 
    let l, u = op l1 u1 l2 u2 in
    Interv (l, u)
  | No_integral _, _ | _, No_integral _ -> assert false
  | _, Z | Z, _ -> Z

and signed_rule op t1 t2 =
  (* probably not the most efficient way to compute the result, but the
     shortest *) 
  let compute l1 u1 l2 u2 = 
    let a = op l1 l2 in
    let b = op l1 u2 in
    let c = op u1 l2 in
    let d = op u1 u2 in
    BI.min a (BI.min b (BI.min c d)), BI.max a (BI.max b (BI.max c d))
  in
  binary_arithmetic compute t1 t2

let compute_quantif_guards_ref
    : (predicate named -> logic_var list -> predicate named -> 
       (term * relation * logic_var * relation * term) list) ref
    = Extlib.mk_fun "compute_quantif_guards_ref"

let rec type_predicate_named p = match p.content with
  | Pfalse | Ptrue -> ()
  | Papp _ -> Error.not_yet "logic function application"
  | Pseparated _ -> Error.not_yet "separated"
  | Prel(_, t1, t2) -> 
    ignore (type_term t1);
    ignore (type_term t2)
  | Pand(p1, p2) | Por(p1, p2) | Pxor(p1, p2) | Pimplies(p1, p2) 
  | Piff(p1, p2) ->
    type_predicate_named p1;
    type_predicate_named p2
  | Pnot p -> type_predicate_named p
  | Pif(t, p1, p2) -> 
    ignore (type_term t);
    type_predicate_named p1;
    type_predicate_named p2
  | Plet _ -> Error.not_yet "let _ = _ in _"
  | Pforall(bounded_vars, { content = Pimplies(hyps, goal) })
  | Pexists(bounded_vars, { content = Pand(hyps, goal) }) ->
    let guards = !compute_quantif_guards_ref p bounded_vars hyps in
    List.iter
      (fun (t1, r1, x, r2, t2) -> 
	let ty1 = type_term t1 in
	let ty1 = match ty1, r1 with
	  | Interv(l, u), Rlt -> Interv(BI.add l BI.one, BI.add u BI.one)
	  | Interv(l, u), Rle -> Interv(l, u)
	  | Z, (Rlt | Rle) -> Z
	  | _, _ -> assert false
	in
	let ty2 = type_term t2 in
	(* add one here, since we increment the loop counter one more time
	   before going out the loop. *)
	let ty2 = match ty2, r2 with
	  | Interv(l, u), Rlt -> Interv(l, u)
	  | Interv(l, u), Rle -> Interv(BI.add l BI.one, BI.add u BI.one)
	  | Z, (Rlt | Rle) -> Z
	  | _, _ -> assert false
	in
	Logic_var_env.add x (join ty1 ty2))
      guards;
    type_predicate_named hyps;
    type_predicate_named goal
  | Pforall _ -> Error.not_yet "unguarded \\forall quantification"
  | Pexists _ -> Error.not_yet "unguarded \\exists quantification"
  | Pat(p, _) -> type_predicate_named p
  | Pvalid _ ->  Error.not_yet "\\valid"
  | Pvalid_index _ -> Error.not_yet "\\valid_index"
  | Pvalid_range _ -> Error.not_yet "\\valid_range"
  | Pfresh _ -> Error.not_yet "\\fresh"
  | Psubtype _ -> Error.not_yet "subtyping relation" (* Jessie specific *)
  | Pinitialized _ -> Error.not_yet "\\initialized"

let type_term t = ignore (type_term t)

let type_named_predicate p = 
  Options.debug ~level:2 "typing predicate %a" d_predicate_named p;
  clear ();
  type_predicate_named p

(******************************************************************************)
(** Subtyping *)
(******************************************************************************)

(* convert [e] in a way that it is compatible with the given typing context. *)
let context_sensitive ?loc env ctx is_mpz_string t_opt e = 
  let ty = typeOf e in
  let mk_mpz e = 
    Env.new_var env t_opt Mpz.t (fun lv v -> [ Mpz.init_set (var lv) v e ])
  in
  let do_int_ctx ty =
    let e, env = if is_mpz_string then mk_mpz e else e, env in
    if Mpz.is_t ty || is_mpz_string then
      (* cast the mpz into a C integer *)
      let name, new_ty = 
	if isSignedInteger ty then 
	  "__gmpz_get_si", longType
	else
	  "__gmpz_get_ui", ulongType 
      in
      Options.warning
	?source:(Extlib.opt_map fst loc)
	~once:true
	"@[missing guard for ensuring that the given integer is \
C-representable@]"; 
     Env.new_var 
       env
       None
       new_ty
       (fun v _ -> [ Misc.mk_call ?loc ~result:(var v) name [ e ] ])
    else
      (if isIntegralType ctx && isIntegralType ty then 
	  mkCast e (arithmeticConversion ctx ty)
       else
	  e),
      env
  in
  if Mpz.is_t ctx then
    if Mpz.is_t ty then
      e, env
    else begin
      (* Convert the C integer into a mpz. 
	 Remember: very long integer constants have been temporary converted
	 into strings *)
      assert (Options.verify
		(isIntegralType ty || is_mpz_string) 
		"how to convert %a to an integer?"
		d_type ty); 
      mk_mpz e
    end
  else if isIntegralType ctx then do_int_ctx ty
  else e, env

let principal_type t1 t2 = 
  let ty1 = typ_of_term t1 in
  let ty2 = typ_of_term t2 in
  (* possible to get an integralType (or Mpz.t) with a non-one in the case of
     \null *)
  if isIntegralType ty1 then
    if isIntegralType ty2 then arithmeticConversion ty1 ty2
    else if Mpz.is_t ty2 then ty2 else ty1
  else if Mpz.is_t ty1 then
    if isIntegralType ty2 || Mpz.is_t ty2 then ty1 else ty2
  else 
    ty2

(*
Local Variables:
compile-command: "make"
End:
*)
