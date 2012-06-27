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

(* ************************************************************************** *)
(* Transforming terms and predicates into C expressions (if any) *)
(* ************************************************************************** *)

let relation_to_binop = function
  | Rlt -> Lt
  | Rgt -> Gt
  | Rle -> Le
  | Rge -> Ge
  | Req -> Eq
  | Rneq -> Ne

let name_of_binop = function
  | Lt -> "lt"
  | Gt -> "gt"
  | Le -> "le"
  | Ge -> "ge"
  | Eq -> "eq"
  | Ne -> "ne"
  | LOr -> "or"
  | LAnd -> "and"
  | BOr -> "bor"
  | BXor -> "bxor"
  | BAnd -> "band"
  | Shiftrt -> "shiftr"
  | Shiftlt -> "shiftl"
  | Mod -> "mod"
  | Div -> "div"
  | Mult -> "mul"
  | PlusA -> "add"
  | MinusA -> "sub"
  | MinusPP | MinusPI | IndexPI | PlusPI -> assert false

let name_of_mpz_arith_bop = function
  | PlusA -> "__gmpz_add"
  | MinusA -> "__gmpz_sub"
  | Mult -> "__gmpz_mul"
  | Div -> "__gmpz_tdiv_q"
  | Mod -> "__gmpz_tdiv_r"
  | Lt | Gt | Le | Ge | Eq | Ne | BAnd | BXor | BOr | LAnd | LOr
  | Shiftlt | Shiftrt | PlusPI | IndexPI | MinusPI | MinusPP -> assert false

let constant_to_exp ?(loc=Location.unknown) = function
  | CInt64(n, k, s) ->
    if Typing.is_representable n k s then kinteger64_repr ?loc k n s, false
    else mkString ?loc (My_bigint.to_string n), true
  | CStr _ | CWStr _ | CChr _ | CReal _ | CEnum _ as c -> 
    new_exp ?loc (Const c), false

let conditional_to_exp ?(name="if") loc ctx e1 (e2, env2) (e3, env3) =
  let env = Env.pop (Env.pop env3) in
  let _, e, env =
    Env.new_var
      ~name
      env
      None
      ctx
      (fun v ev -> 
	let lv = var v in
	let affect e = Mpz.init_set lv ev e in
	let then_block, _ = 
	  let s = affect e2 in
	  Env.pop_and_get env2 s ~global_clear:false Env.Middle
	in
	let else_block, _ = 
	  let s = affect e3 in
	  Env.pop_and_get env3 s ~global_clear:false Env.Middle
	in
	[ mkStmt ~valid_sid:true (If(e1, then_block, else_block, loc)) ])
  in
  e, env

let rec thost_to_host env = function
  | TVar { lv_origin = Some v } -> Var v, env, v.vname
  | TVar ({ lv_origin = None } as logic_v) -> 
    Var (Env.Logic_binding.get env logic_v), env, logic_v.lv_name
  | TResult _typ -> 
    let vis = Env.get_visitor env in
    let kf = Extlib.the vis#current_kf in
    let stmt = 
      try Kernel_function.find_return kf 
      with Kernel_function.No_Statement -> assert false
    in
    (match stmt.skind with
    | Return(Some { enode = Lval (lhost, NoOffset) }, _) -> lhost, env, "result"
    | _ -> assert false)
  | TMem t ->
    let e, env = term_to_exp env None t in
    Options.warning ~source:(fst e.eloc) ~once:true
      "@[missing guard for ensuring that@ %a is a valid memory access@]"
      d_term t;
    Mem e, env, ""

and toffset_to_offset ?loc env = function
  | TNoOffset -> NoOffset, env
  | TField(f, offset) -> 
    (* TODO: still untested *)
    let offset, env = toffset_to_offset ?loc env offset in
    Field(f, offset), env
  | TIndex(t, offset) -> 
    let e, env = term_to_exp env (Some intType) t in
    Options.warning ~source:(fst e.eloc) ~once:true
      "@[missing guard for ensuring that@ %a is a valid array index@]"
      d_term t;
    let offset, env = toffset_to_offset env offset in
    Index(e, offset), env
  | TModel _ -> Error.not_yet "model"

and tlval_to_lval env (host, offset) = 
  let host, env, name = thost_to_host env host in
  let offset, env = toffset_to_offset env offset in
  let name = match offset with NoOffset -> name | Field _ | Index _ -> "" in
  (host, offset), env, name

(* the returned boolean says is the expression is an mpz_string;
   the returned string is the name of the generated variable corresponding to
   the term. *)
and context_insensitive_term_to_exp env t = 
  let loc = t.term_loc in
  match t.term_node with
  | TConst c -> 
    let c, is_mpz_string = constant_to_exp ~loc c in
    c, env, is_mpz_string, ""
  | TLval lv -> 
    let lv, env, name = tlval_to_lval env lv in
    new_exp ~loc (Lval lv), env, false, name
  | TSizeOf ty -> sizeOf ~loc ty, env, false, "sizeof"
  | TSizeOfE t ->
    let ctx = match t.term_type with Ctype ty -> ty | _ -> assert false in
    let e, env = term_to_exp env (Some ctx) t in
    sizeOf ~loc (typeOf e), env, false, "sizeof"
  | TSizeOfStr s -> new_exp ~loc (SizeOfStr s), env, false, "sizeofstr"
  | TAlignOf ty -> new_exp ~loc (AlignOf ty), env, false, "alignof"
  | TAlignOfE t ->
    let ctx = match t.term_type with Ctype ty -> ty | _ -> assert false in
    let e, env = term_to_exp env (Some ctx) t in
    new_exp ~loc (AlignOfE e), env, false, "alignof"
  | TUnOp(Neg | BNot as op, t') ->
    let ty = Typing.typ_of_term t in
    let e, env = term_to_exp env (Some ty) t' in
    if Mpz.is_t ty then
      let name, vname = match op with
	| Neg -> "__gmpz_neg", "neg"
	| BNot -> "__gmpz_com", "bnot"
	| LNot -> assert false
      in
      let _, e, env = 
	Env.new_var_and_mpz_init
	  env
	  ~name:vname
	  (Some t)
	  (fun _ ev -> [ Misc.mk_call ~loc name [ ev; e ] ])
      in
      e, env, false, ""
    else begin
      assert (isIntegralType ty);
      new_exp ~loc (UnOp(op, e, ty)), env, false, ""
    end
  | TUnOp(LNot, t) ->
    let ty = Typing.typ_of_term t in
    if Mpz.is_t ty then
      (* [!t] is converted into [t == 0] *)
      let zero = Logic_const.tinteger ~ikind:IInt 0 in
      let e, env = comparison_to_exp ~loc ~name:"not" env Eq t zero (Some t) in
      e, env, false, ""
    else begin
      assert (isIntegralType ty);
      let e, env = term_to_exp env None t in
      new_exp ~loc (UnOp(LNot, e, intType)), env, false, ""
    end
  | TBinOp(PlusA | MinusA | Mult as bop, t1, t2) ->
    let ty = Typing.typ_of_term t in
    let ctx = Some ty in
    let e1, env = term_to_exp env ctx t1 in
    let e2, env = term_to_exp env ctx t2 in
    if Mpz.is_t ty then
      let name = name_of_mpz_arith_bop bop in
      let mk_stmts _ e = [ Misc.mk_call ~loc name [ e; e1; e2 ] ] in
      let name = name_of_binop bop in
      let _, e, env = Env.new_var_and_mpz_init ~name env (Some t) mk_stmts in
      e, env, false, ""
    else
      new_exp ~loc (BinOp(bop, e1, e2, ty)), env, false, ""
  | TBinOp(Div | Mod as bop, t1, t2) ->
    let ty = Typing.typ_of_term t in
    let ctx = Some ty in
    let e1, env = term_to_exp env ctx t1 in
    let e2, env = term_to_exp env ctx t2 in
    (* [TODO] can now do better since the type system got some info about
       possible values of [t2] *)
    (* guarding divisions and modulos *)
    let zero = Logic_const.tinteger ~ikind:IInt 0 in
    (* do not generate [e2] from [t2] twice *)
    let guard, env = 
      let name = name_of_binop bop ^ "_guard" in
      comparison_to_exp env ~e1:(e2, ty) ~name Eq t2 zero (Some t) 
    in
    let mk_stmts v e = 
      let name = name_of_mpz_arith_bop bop in
      let cond = 
	Misc.mk_e_acsl_guard 
	  (Env.annotation_kind env) 
	  guard
	  (Logic_const.prel ~loc (Req, t2, zero)) 
      in
      Env.add_assert env cond (Logic_const.prel (Rneq, t2, zero));
      let instr = 
	if Mpz.is_t ty then Misc.mk_call ~loc name [ e; e1; e2 ]
	else begin
	  assert (isIntegralType ty);
	  let e = new_exp ~loc (BinOp(bop, e1, e2, ty)) in
	  mkStmtOneInstr ~valid_sid:true (Set((Var v, NoOffset), e, loc))
	end
      in
      [ cond; instr ]
    in
    let t = Some t in
    let _, e, env = 
      let name = name_of_binop bop in
      if Mpz.is_t ty then Env.new_var_and_mpz_init ~name env t mk_stmts
      else begin
	assert (isIntegralType ty);
	Env.new_var ~name env t ty mk_stmts 
      end
    in
    e, env, false, ""
  | TBinOp(Lt | Gt | Le | Ge | Eq | Ne as bop, t1, t2) ->
    (* comparison operators *)
    let e, env = comparison_to_exp ~loc env bop t1 t2 (Some t) in
    e, env, false, ""
  | TBinOp((Shiftlt | Shiftrt), _, _) ->
    (* left/right shift *)
    Error.not_yet "left/right shift"
  | TBinOp(LOr, t1, t2) ->
    (* t1 || t2 <==> if t1 then true else t2 *)
    let ty = Typing.principal_type t1 t2 in
    let e1, env1 = term_to_exp env (Some intType) t1 in
    let env' = Env.push env1 in
    let res2 = term_to_exp (Env.push env') (Some ty) t2 in
    let e, env = conditional_to_exp ~name:"or" loc ty e1 (one loc, env') res2 in
    e, env, false, ""
  | TBinOp(LAnd, t1, t2) ->
    (* t1 && t2 <==> if t1 then t2 else false *)
    let ty = Typing.principal_type t1 t2 in
    let e1, env1 = term_to_exp env (Some intType) t1 in
    let _, env2 as res2 = term_to_exp (Env.push env1) (Some ty) t2 in
    let env3 = Env.push env2 in
    let e, env = 
      conditional_to_exp ~name:"and" loc ty e1 res2 (zero loc, env3) 
    in
    e, env, false, ""
  | TBinOp((BOr | BXor | BAnd), _, _) ->
    (* other logic/arith operators  *)
    Error.not_yet "missing binary bitwise operator"
  | TBinOp(PlusPI | IndexPI | MinusPI | MinusPP as bop, t1, t2) ->
    (* binary operation over pointers *)
    (* [TODO] untested *)
    let ctx1, ctx2, ty = 
      (* ISO C, Section 6.5.6: either the first argument is a pointer and the
	 second is an integer type, or the reverse *)
      let ty1 = Typing.typ_of_term t1 in
      let ty2 = Typing.typ_of_term t2 in
      if Mpz.is_t ty1 then Some longType, Some ty2, ty2
      else if Mpz.is_t ty2 then Some ty1, Some longType, ty1
      else Some ty1, Some ty2, if isIntegralType ty1  then ty2 else ty1
    in
    let e1, env = term_to_exp env ctx1 t1 in
    let e2, env = term_to_exp env ctx2 t2 in
    Options.warning ~source:(fst loc) ~once:true
      "@[missing guard for ensuring that@ %a is a valid pointer@]"
      d_term t;
    new_exp ~loc (BinOp(bop, e1, e2, ty)), env, false, ""
  | TCastE(ty, t) ->
    let e, env = term_to_exp env (Some ty) t in
    mkCast e ty, env, false, "cast"
  | TAddrOf lv -> 
    let lv, env, _ = tlval_to_lval env lv in
    mkAddrOf ~loc lv, env, false, "addrof"
  | TStartOf lv -> 
    let lv, env, _ = tlval_to_lval env lv in
    mkAddrOrStartOf ~loc lv, env, false, "startof"
  | Tapp _ -> Error.not_yet "applying logic function"
  | Tlambda _ -> Error.not_yet "functional"
  | TDataCons _ -> Error.not_yet "constructor"
  | Tif(t1, t2, t3) -> 
    let e1, env1 = term_to_exp env (Some intType) t1 in
    let ty = Typing.principal_type t2 t3 in
    let ctx = Some ty in
    let (_, env2 as res2) = term_to_exp (Env.push env1) ctx t2 in
    let res3 = term_to_exp (Env.push env2) ctx t3 in
    let e, env = conditional_to_exp loc ty e1 res2 res3 in
    e, env, false, ""
  | Tat(t', label) ->
    (* convert [t'] to [e] in a separated local env *)
    let e, env = term_to_exp (Env.push env) None t' in
    let e, env, is_mpz_string = at_to_exp env (Some t) label e in
    e, env, is_mpz_string, ""
  | Tbase_addr _ -> Error.not_yet "\\base_addr"
  | Toffset _ -> Error.not_yet "\\offset"
  | Tblock_length _ -> Error.not_yet "\\block_length"
  | Tnull -> mkCast (zero ~loc) (TPtr(TVoid [], [])), env, false, "null"
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

(* Convert an ACSL term into a corresponding C expression (if any) in the given
   environment. Also extend this environment in order to include the generating
   constructs. *)
and term_to_exp env ctx t = 
  let e, env, is_mpz_string, name = context_insensitive_term_to_exp env t in
  match ctx with
  | None -> e, env
  | Some ty -> 
    let name = if name = "" then None else Some name in
    Typing.context_sensitive
      ~loc:t.term_loc
      ?name
      env
      ty
      is_mpz_string
      (Some t) 
      e

(* generate the C code equivalent to [t1 bop t2]. *)
and comparison_to_exp
    ?(loc=Location.unknown) ?e1 env bop ?(name=name_of_binop bop) t1 t2 t_opt =
  let e1, env, ctx = match e1 with
    | None -> 
      let ctx = Typing.principal_type t1 t2  in
      let e1, env = term_to_exp env (Some ctx) t1 in
      e1, env, ctx
    | Some(e1, ctx) -> 
      e1, env, ctx
  in
  let e2, env = term_to_exp env (Some ctx) t2 in
  if Mpz.is_t ctx then
    let _, e, env =
      Env.new_var
	env
	t_opt
	~name
	intType
	(fun v _ -> [ Misc.mk_call ~result:(var v) "__gmpz_cmp" [ e1; e2 ] ])
    in
    new_exp ?loc (BinOp(bop, e, zero ?loc, intType)), env
  else
    new_exp ?loc (BinOp(bop, e1, e2, intType)), env

and at_to_exp env t_opt label e =
  let stmt = Env.stmt_of_label env label in
  (* generate a new variable denoting [\at(t',label)].
     That is this variable which is the resulting expression. 
     ACSL typing rule ensures that the type of this variable is the same as
     the one of [e]. *)
  let res_v, res, new_env =
    Env.new_var ~name:"at" ~global:true env t_opt (typeOf e) (fun _ _ -> [])
  in
  let env_ref = ref new_env in
  (* visitor modifying in place the labeled statement in order to store [e]
     in the resulting variable at this location which is the only correct
     one. *)
  let o = object 
    inherit Visitor.frama_c_inplace
    method vstmt_aux stmt = 
      (* either a standard C affectation or an mpz one according to type of
	 [e] *) 
      let new_stmt = Mpz.init_set (var res_v) res e in
      assert (!env_ref == new_env);
      (* generate the new block of code for the labeled statement and the
	 corresponding environment *)
      let block, new_env = 
	Env.pop_and_get new_env new_stmt ~global_clear:false Env.Middle
      in
      let pre = match label with
	| LogicLabel(_, s) when s = "Here" || s = "Post" -> true
	| StmtLabel _ | LogicLabel _ -> false
      in
      env_ref := Env.extend_stmt_in_place new_env stmt ~pre block;
      ChangeTo stmt
  end
  in
  let bhv = (Env.get_visitor new_env)#behavior in
  let new_stmt = Visitor.visitFramacStmt o (get_stmt bhv stmt) in
  set_stmt bhv stmt new_stmt;
  res, !env_ref, false

(* Convert an ACSL named predicate into a corresponding C expression (if
   any) in the given environment. Also extend this environment which includes
   the generating constructs. *)
let rec named_predicate_to_exp ?name env p = 
  let loc = p.loc in
  match p.content with
  | Pfalse -> zero ~loc, env
  | Ptrue -> one ~loc, env
  | Papp _ -> Error.not_yet "logic function application"
  | Pseparated _ -> Error.not_yet "separated"
  | Prel(rel, t1, t2) -> 
    let e, env = 
      comparison_to_exp ~loc env (relation_to_binop rel) t1 t2 None 
    in
    Typing.context_sensitive ~loc env intType false None e
  | Pand(p1, p2) ->
    (* p1 && p2 <==> if p1 then p2 else false *)
    let e1, env1 = named_predicate_to_exp env p1 in
    let _, env2 as res2 = named_predicate_to_exp (Env.push env1) p2 in
    let env3 = Env.push env2 in
    let name = match name with None -> "and" | Some n -> n in
    conditional_to_exp ~name loc intType e1 res2 (zero loc, env3)
  | Por(p1, p2) -> 
    (* p1 || p2 <==> if p1 then true else p2 *)
    let e1, env1 = named_predicate_to_exp env p1 in
    let env' = Env.push env1 in
    let res2 = named_predicate_to_exp (Env.push env') p2 in
    let name = match name with None -> "or" | Some n -> n in
    conditional_to_exp ~name loc intType e1 (one loc, env') res2
  | Pxor _ -> Error.not_yet "xor"
  | Pimplies(p1, p2) -> 
    (* (p1 ==> p2) <==> !p1 || p2 *)
    named_predicate_to_exp 
      ~name:"implies"
      env
      (Logic_const.por ~loc ((Logic_const.pnot ~loc p1), p2))
  | Piff(p1, p2) -> 
    (* (p1 <==> p2) <==> (p1 ==> p2 && p2 ==> p1) *)
    named_predicate_to_exp 
      ~name:"equiv"
      env
      (Logic_const.pand ~loc
	 (Logic_const.pimplies ~loc (p1, p2), 
	  Logic_const.pimplies ~loc (p2, p1)))
  | Pnot p ->
    let e, env = named_predicate_to_exp env p in
    new_exp ~loc (UnOp(LNot, e, intType)), env
  | Pif(t, p2, p3) ->
    let e1, env1 = term_to_exp env (Some intType) t in
    let (_, env2 as res2) = named_predicate_to_exp (Env.push env1) p2 in
    let res3 = named_predicate_to_exp (Env.push env2) p3 in
    conditional_to_exp loc intType e1 res2 res3
  | Plet _ -> Error.not_yet "let _ = _ in _"
  | Pforall _ | Pexists _ -> Quantif.quantif_to_exp env p
  | Pat(p, label) -> 
    (* convert [t'] to [e] in a separated local env *)
    let e, env = named_predicate_to_exp (Env.push env) p in
    let e, env, is_string = at_to_exp env None label e in
    assert (not is_string);
    e, env
  | Pvalid _ -> Error.not_yet "\\valid"
  | Pvalid_read _ ->  Error.not_yet "\\valid_read"
  | Pallocable _ -> Error.not_yet "\\allocate"
  | Pfreeable _ -> Error.not_yet "\\free"
  | Pfresh _ -> Error.not_yet "\\fresh"
  | Psubtype _ -> Error.not_yet "subtyping relation" (* Jessie specific *)
  | Pinitialized _ -> Error.not_yet "\\initialized"

let () = 
  Quantif.term_to_exp_ref := term_to_exp;
  Quantif.named_predicate_to_exp_ref := named_predicate_to_exp

(* ************************************************************************** *)
(* [convert_*] converts a given ACSL annotation into the corresponding C
   statement (if any) for runtime assertion checking *)
(* ************************************************************************** *)

let assumes_predicate bhv =
  List.fold_left
    (fun acc p -> Logic_const.pand (acc, Logic_const.unamed p.ip_content))
    Logic_const.ptrue
    bhv.b_assumes

let convert_named_predicate env p =
  Typing.type_named_predicate p;
  let e, env = named_predicate_to_exp env p in
  assert (Typ.equal (typeOf e) intType);
  Env.add_stmt
    env
    (Misc.mk_e_acsl_guard ~reverse:true (Env.annotation_kind env) e p)

let convert_preconditions env behaviors =
  let env = Env.set_annotation_kind env Misc.Precondition in
  let do_behavior env b = 
    let assumes_pred = assumes_predicate b in
    List.fold_left
      (fun env p ->
	let do_it env =
	  let loc = p.ip_loc in
	  let p = 
	    Logic_const.pimplies
	      ~loc
	      (assumes_pred, Logic_const.unamed ~loc p.ip_content)
	  in
	  convert_named_predicate env p
	in
	Error.handle do_it env)
      env
      b.b_requires
  in 
  List.fold_left do_behavior env behaviors

let convert_postconditions env behaviors =
  let env = Env.set_annotation_kind env Misc.Postcondition in
  (* generate one guard by postcondition of each behavior *)
  let do_behavior env b = 
    let assumes_pred = assumes_predicate b in
    List.fold_left
      (fun env (t, p) ->
	let do_it env =
	  if b.b_assigns <> WritesAny then 
	    Error.not_yet "assigns clause in behavior";
	  if b.b_extended <> [] then 
	    Error.not_yet "grammar extensions in behavior";
	  match t with
	  | Normal -> 
	    let loc = p.ip_loc in
	    let p = p.ip_content in
	    let p = 
	      Logic_const.pimplies 
		~loc
		(Logic_const.pold ~loc assumes_pred, Logic_const.unamed ~loc p) 
	    in
	    convert_named_predicate env p
	  | Exits | Breaks | Continues | Returns ->
	    Error.not_yet "@[abnormal termination case in behavior@]"
	in
	Error.handle do_it env)
      env
      b.b_post_cond
  in 
  List.fold_left do_behavior env behaviors

let convert_pre_spec env spec =
  let convert env =
    if spec.spec_variant <> None then Error.not_yet "variant clause";
    if spec.spec_terminates <> None then Error.not_yet "terminates clause";
    if spec.spec_complete_behaviors <> [] then 
      Error.not_yet "complete behavior";
    if spec.spec_disjoint_behaviors <> [] then 
      Error.not_yet "disjoint behavior";
    convert_preconditions env spec.spec_behavior
  in
  Error.handle convert env

let convert_post_spec env spec = 
  Error.handle (fun env -> convert_postconditions env spec.spec_behavior) env

let convert_pre_code_annotation env annot =
  let convert env = match annot.annot_content with
    | AAssert(l, p) | AInvariant(l, false (* invariant as assertion *), p) 
	as a -> 
      let kind = match a with 
	| AAssert _ -> Misc.Assertion
	| AInvariant _ -> Misc.Invariant
	| _ -> assert false
      in
      let env = Env.set_annotation_kind env kind in
      if l <> [] then 
	Error.not_yet "@[assertions applied only on some behaviors@]";
      convert_named_predicate env p
    | AStmtSpec(l, spec) ->
      if l <> [] then 
        Error.not_yet "@[statement contract applied only on some behaviors@]";
      convert_pre_spec env spec ;
    | AInvariant(_, b, _) -> assert b; Error.not_yet "loop invariant"
    | AVariant _ -> Error.not_yet "variant"
    | AAssigns _ -> Error.not_yet "assigns"
    | AAllocation _ -> Error.not_yet "allocation"
    | APragma _ -> Error.not_yet "pragma"
  in
  Error.handle convert env

let convert_post_code_annotation env annot =
  let convert env = match annot.annot_content with
    | AStmtSpec(_, spec) -> convert_post_spec env spec
    | AAssert _ 
    | AInvariant _ 
    | AVariant _
    | AAssigns _
    | AAllocation _
    | APragma _ -> env
  in
  Error.handle convert env

(* ************************************************************************** *)
(* Visitor *)
(* ************************************************************************** *)

(* local references to the below visitor and to [do_visit] *)
let first_global = ref true
let function_env = ref Env.dummy
let funspec = ref (Cil.empty_funspec ())

(* the main visitor performing e-acsl checking and C code generator *)
class e_acsl_visitor prj generate = object (self)

  inherit Visitor.generic_frama_c_visitor 
    prj 
    ((if generate then copy_visit else inplace_visit) ())

  method private reset_env () =
    function_env := Env.empty (self :> Visitor.frama_c_visitor)

  method vfile f =
    (* copy the options used during the visit in the new project: it is the
       right place to do this: it is still before visiting, but after
       that the visitor internals reset all of them :-(. *)
    let cur = Project.current () in
    let must_copy = not (Project.equal cur prj) in
    let selection = 
      State_selection.of_list [ Options.Gmp_only.self; Options.Check.self ] 
    in
    if must_copy then Project.copy ~selection ~src:cur prj;
    ChangeDoChildrenPost
      (f, 
       fun f ->
	 (* reset them at the end to be observationally equivalent to a standard
	    visitor. *) 
	 if must_copy then Project.clear ~selection ~project:prj ();
	 f)

  method vglob_aux g =
    if !first_global then begin
      first_global := false;
      if Options.Check.get () then DoChildren
      else ChangeDoChildrenPost([ g ], fun l -> Misc.e_acsl_header () :: l)
    end else
      DoChildren

  (* [TODO] handle integer constants in initializer
     BUT almost impossible without a main entry point *)
  (*  method vinit v off i = assert false *)

  method vvdec vi = 
    try
      let old_vi = get_original_varinfo self#behavior vi in
      let old_kf = Globals.Functions.get old_vi in
      funspec :=
	Cil.visitCilFunspec
	(self :> Cil.cilVisitor)
	(Annotations.funspec old_kf);
      DoChildren
    with Not_found ->
      (* function without code *)
      (* TODO: do better *)
      DoChildren

  method vfunc f =
    let add_gen_vars f = 
      let vars = Env.get_generated_variables !function_env in
      self#reset_env ();
      f.slocals <- f.slocals @ vars;
      let body = f.sbody in
      body.blocals <- body.blocals @ vars;
      f
    in
    ChangeDoChildrenPost(f, add_gen_vars)

  method private is_return stmt = match self#current_kf with
  | None -> assert false
  | Some old_kf -> 
    let old_ret = 
      try Kernel_function.find_return old_kf
      with Kernel_function.No_Statement -> assert false
    in
    Stmt.equal stmt (get_stmt self#behavior old_ret)

  method private is_first_stmt stmt =
    try 
      Stmt.equal
	(get_original_stmt self#behavior stmt) 
	(Kernel_function.find_first_stmt (Extlib.the self#current_kf))
    with Kernel_function.No_Statement -> 
      assert false

  method vstmt_aux stmt =
    Options.debug ~level:2 "proceeding stmt (sid %d) %a@." 
      stmt.sid Stmt.pretty stmt;
    let env = Env.push !function_env in
    let env = 
      if self#is_first_stmt stmt then
	(* convert the precondition of the function *)
	Project.on prj (convert_pre_spec env) !funspec
      else
	env
    in
    (* [TODO] potential BUG HERE since the annotations tbl is the one of the old
       project. *)
    let env, new_annots =
      Annotations.fold_code_annot
	(fun _ (User old_a | AI(_, old_a)) (env, new_annots) -> 
	  let a =
            (* [VP] Don't use Visitor here, as it will fill the
	       queue in the middle of the computation... *)
	    Cil.visitCilCodeAnnotation (self :> Cil.cilVisitor) old_a
	  in
	  let env = Project.on prj (convert_pre_code_annotation env) a in
	  env, a :: new_annots)
	(get_original_stmt self#behavior stmt)
	(env, [])
    in
    function_env := env;
    let mk_block stmt =
      (* be careful: as this function is called in a post action, [env] has
	 been modified since pre actions have been executed.
	 Use [function_env] to get it back. *)
      let env = !function_env in
      let mk_block b = mkStmt ~valid_sid:true (Block b) in
      let mk_post_env env =
	(* [fold_right] to preserve order of generation of pre_conditions *) 
	Project.on
	  prj
	  (List.fold_right
	     (fun a env -> convert_post_code_annotation env a)
	     new_annots)
	  env
      in
      let new_stmt, env = 
	if self#is_return stmt then 
	  (* must generate the post_block before including [stmt] (the 'return')
	     since no code is executed after it. However, since this statement
	     is pure (Cil invariant), that is semantically correct. *)
	  let env = mk_post_env env in
	  (* also handle the postcondition of the function and clear the env *)
	  let env = Project.on prj (convert_post_spec env) !funspec in
	  let b, env = Env.pop_and_get env stmt ~global_clear:true Env.After in
	  let new_stmt = mk_block b in
	  let labels = stmt.labels in
	  (match labels with
	  | [] -> ()
	  | _ :: _ ->
	    (* move the labels of the return to the new block in order to
	       evaluate the postcondition when jumping to them. *)
	    stmt.labels <- [];
	    new_stmt.labels <- labels @ new_stmt.labels;
	    (* update the gotos of the function jumping to one of the labels *)
	    let o = object 
	      inherit Visitor.frama_c_inplace
	      method vstmt_aux s = match s.skind with
	      | Goto(s_ref, _) -> 
		(* [!s_ref] and [stmt] are not part of the same project, thus it
		   is safer to compare the ids than to use Stmt.equal *)
		if !s_ref.sid = stmt.sid then s_ref := new_stmt; 
		SkipChildren
	      | _ -> DoChildren
	      (* improve efficiency: skip childrens of vstmt which cannot
		 contain any stmt *)
	      method vinst _ = SkipChildren
	      method vexpr _ = SkipChildren
	      method vcode_annot _ = SkipChildren
	      method vlval _ = SkipChildren
	    end in
	    let vis = Env.get_visitor env in
	    let f = Extlib.the vis#current_func in
	    let mv_label s =
	      ignore (Visitor.visitFramacStmt o (get_stmt vis#behavior s))
	    in
	    List.iter mv_label f.sallstmts);
	  new_stmt, env
	else
	  (* must generate [pre_block] which includes [stmt] before generating
	     [post_block] *)
	  let pre_block, env = 
	    Env.pop_and_get env stmt ~global_clear:false Env.After
	  in
	  let env = mk_post_env (Env.push env) in
	  let post_block, env = 
	    Env.pop_and_get 
	      env (mk_block pre_block) ~global_clear:false Env.Before 
	  in
	  (* TODO: must clear the local block anytime (?) *)
	  mk_block post_block, env
      in
      function_env := env;
      Options.debug ~level:3
	"@[new stmt (from sid %d):@ %a@]" stmt.sid d_stmt new_stmt;
      new_stmt
    in
    ChangeDoChildrenPost(stmt, mk_block)

  initializer self#reset_env ()

end

let do_visit ?(prj=Project.current ()) generate =
  let vis =
    Extlib.try_finally ~finally:Typing.clear (new e_acsl_visitor prj) generate
  in
  first_global := true;
  (* explicit type annotation in order to check that no new method is
     introduced by error *)
  (vis : Visitor.frama_c_visitor)

(*
Local Variables:
compile-command: "make"
End:
*)
