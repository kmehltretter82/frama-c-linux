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

(* ************************************************************************** *)
(* Typing rules *)
(* ************************************************************************** *)

let compatible_type ty ty' = 
  (* compatible if the two type has the same "integrality" *)
  (* not (ty xor ty') *)
  (isIntegralType ty && isIntegralType ty')
  || (not (isIntegralType ty || isIntegralType ty'))

(* convert [e] corresponding to a term of type [ty] in a way that it is
   compatible with the given context. *)
let context_sensitive ?loc env ctx is_mpz_string e = 
  let ty = typeOf e in
  let mk_mpz env e = Env.new_var env Mpz.t (fun _ v -> [ Mpz.init_set v e ]) in
  let do_int_ctx ty' =
    let e, env = if is_mpz_string then mk_mpz env e else e, env in
    if Mpz.is_t ty || is_mpz_string then
      (* cast the mpz into a C integer *)
      let name = if isSignedInteger ty' then "mpz_get_si" else "mpz_get_ui" in
      Options.warning
	?source:(Extlib.opt_map fst loc)
	~once:true
	"missing guard for ensuring that the given integer is C-representable"; 
      Env.new_var 
	env
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
	 Remember: very long integer constant has bee, temporary converted into
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
  | Ctype tty, Ctype tty' -> 
    assert (compatible_type tty tty');
    ty
  | Ctype _, Linteger | Linteger, Ctype _ -> assert false
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
      ty
  in
  principal_type (typ t1) (typ t2)

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

let name_of_mpz_arith_bop = function
  | PlusA -> "mpz_add"
  | MinusA -> "mpz_sub"
  | Mult -> "mpz_mul"
  | Div -> "mpz_cdiv_q"
  | Mod -> "mpz_mod_ui"
  | Lt | Gt | Le | Ge | Eq | Ne | BAnd | BXor | BOr | LAnd | LOr
  | Shiftlt | Shiftrt | PlusPI | IndexPI | MinusPI | MinusPP -> assert false

let is_representable _n k _s = match k with
  | IBool | IChar | IUChar | IUInt | IUShort | IULong | ISChar | IShort | IInt
  | ILong ->
    true
  | ILongLong | IULongLong ->
    false

let constant_to_exp ?(loc=Location.unknown) = function
  | CInt64(n, k, s) ->
    if is_representable n k s then kinteger64_repr ?loc k n s, false
    else mkString ?loc (My_bigint.to_string n), true
  | CStr _ | CWStr _ | CChr _ | CReal _ | CEnum _ as c -> 
    new_exp ?loc (Const c), false

let rec thost_to_host env = function
  | TVar { lv_origin = Some v } -> Var v, env
  | TVar { lv_origin = None } -> Misc.not_yet "logic variable"
  | TResult _typ -> Misc.not_yet "\\result"
  | TMem t ->
    let e, env = term_to_exp env (Ctype intType) t in
    Options.warning ~source:(fst e.eloc) ~once:true
      "missing guard for ensuring that %a is a valid memory access"
      d_term t;
    Mem e, env

and toffset_to_offset ?loc env = function
  | TNoOffset -> NoOffset, env
  | TField(f, offset) -> 
    (* TODO: still untested *)
    let offset, env = toffset_to_offset ?loc env offset in
    Field(f, offset), env
  | TIndex(t, offset) -> 
    let e, env = term_to_exp env (Ctype intType) t in
    Options.warning ~source:(fst e.eloc) ~once:true
      "missing guard for ensuring that %a is a valid array index"
      d_term t;
    let offset, env = toffset_to_offset env offset in
    Index(e, offset), env

and tlval_to_lval env (host, offset) = 
  let host, env = thost_to_host env host in
  let offset, env = toffset_to_offset env offset in
  (host, offset), env

and context_insensitive_term_to_exp env t = 
  let loc = t.term_loc in
  match t.term_node with
  | TConst c -> 
    let c, is_mpz_string = constant_to_exp ~loc c in
    c, env, is_mpz_string
  | TLval lv -> 
    let lv, env = tlval_to_lval env lv in
    new_exp ~loc (Lval lv), env, false
  | TSizeOf ty -> sizeOf ~loc ty, env, false
  | TSizeOfE t ->
    let ty = t.term_type in
    assert (match ty with Ctype _ -> true | _ -> false);
    let e, env = term_to_exp env ty t in
    sizeOf ~loc (typeOf e), env, false
  | TSizeOfStr s -> new_exp ~loc (SizeOfStr s), env, false
  | TAlignOf ty -> new_exp ~loc (AlignOf ty), env, false
  | TAlignOfE t ->
    let ty = t.term_type in
    assert (match ty with Ctype _ -> true | _ -> false);
    let e, env = term_to_exp env ty t in
    new_exp ~loc (AlignOfE e), env, false
  | TUnOp(Neg | BNot as op, t) ->
    let e, env = term_to_exp env Linteger t in
    let name = match op with
      | Neg -> "mpz_neg"
      | BNot -> "mpz_com"
      | LNot -> assert false
    in
    let e, env = 
      Env.new_var_and_mpz_init 
	env
	(fun _ ev -> [ Misc.mk_call ~loc name [ ev; e ] ])
    in
    e, env, false
  | TUnOp(LNot, t) ->
    let ty = t.term_type in
    let e, env = term_to_exp env ty t in
    (* TODO: preserve the old behavior. But that is incorrect if [t] is an 
       integer since we have to implement a ! over mpz values.
       Such a case is actually possible. *)
    assert (not (Mpz.is_t (typeOf e)));
    new_exp ~loc (UnOp(LNot, e, intType)), env, false
  | TBinOp(PlusA | MinusA | Mult as bop, t1, t2) ->
    (* arithmetic binary operator not safely convertible into C *)
    let e1, env = term_to_exp env Linteger t1 in
    let e2, env = term_to_exp env Linteger t2 in
    assert (Typ.equal (typeOf e1) (typeOf e2));
    let name = name_of_mpz_arith_bop bop in
    let mk_stmts _ e = [ Misc.mk_call ~loc name [ e; e1; e2 ] ] in
    let e, env = Env.new_var_and_mpz_init env mk_stmts in
    e, env, false
  | TBinOp(Div | Mod as bop, t1, t2) ->
    (* arithmetic binary operator potentially convertible into C *)
    let ctx = principal_type_from_term t1 t2 in
    let e1, env = term_to_exp env ctx t1 in
    let e2, env = term_to_exp env ctx t2 in
    (* guarding divisions and modulos *)
    let zero = Logic_const.tinteger ~ikind:IInt 0 in
    (* do not generate [e2] from [t2] twice *)
    let guard, env = comparison_to_exp env ~e1:(e2, ctx) Eq t2 zero in
    let mk_stmts v e = 
      let name = name_of_mpz_arith_bop bop in
      let cond = 
	Misc.mk_e_acsl_guard guard (Logic_const.prel (Req, t2, zero)) 
      in
      Env.add_assert cond (Logic_const.prel (Rneq, t2, zero));
      let instr = match ctx with
	| Ctype ty when isIntegralType ty -> 
	  let e = new_exp ~loc (BinOp(bop, e1, e2, ty)) in
	  mkStmtOneInstr ~valid_sid:true (Set((Var v, NoOffset), e, loc))
	| Linteger -> Misc.mk_call ~loc name [ e; e1; e2 ]
	| _ -> assert false
      in
      [ cond; instr ]
    in
    let e, env = match ctx with
      | Ctype ty when isIntegralType ty -> Env.new_var env ty mk_stmts 
      | Linteger -> Env.new_var_and_mpz_init env mk_stmts
      | _ -> assert false
    in
    e, env, false
  | TBinOp(Lt | Gt | Le | Ge | Eq | Ne as bop, t1, t2) ->
    (* comparison operators *)
    let e, env = comparison_to_exp ~loc env bop t1 t2 in
    e, env, false
  | TBinOp((Shiftlt | Shiftrt), _, _) ->
    (* left/right shift *)
    Misc.not_yet "left/right shift"
  | TBinOp((LOr | LAnd | BOr | BXor | BAnd), _, _) ->
    (* other logic/arith operators  *)
    Misc.not_yet "missing binary operator"
  | TBinOp(PlusPI | IndexPI | MinusPI | MinusPP as bop, t1, t2) ->
    (* binary operation over pointers *)
    (* [TODO] untested *)
    let ctx_type t = match t.term_type with
      | Linteger -> 
	(* convert integer to int type for pointer arith *)
	Ctype intType 
      | ty -> ty
    in
    let e1, env = term_to_exp env (ctx_type t1) t1 in
    let e2, env = term_to_exp env (ctx_type t2) t2 in
    Options.warning ~source:(fst loc) ~once:true
      "missing guard for ensuring that %a is a valid pointer"
      d_term t;
    (* the type of the result is the same than type of the pointer [e1],
       whatever is [e2] *)
    new_exp ~loc (BinOp(bop, e1, e2, typeOf e1)), env, false
  | TCastE(ty, t) ->
    let e, env = term_to_exp env (Ctype ty) t in
    mkCast e ty, env, false
  | TAddrOf lv -> 
    let lv, env = tlval_to_lval env lv in
    mkAddrOf ~loc lv, env, false
  | TStartOf lv -> 
    let lv, env = tlval_to_lval env lv in
    mkAddrOrStartOf ~loc lv, env, false
  | Tapp _ -> Misc.not_yet "applying logic function"
  | Tlambda _ -> Misc.not_yet "functional"
  | TDataCons _ -> Misc.not_yet "constructor"
  | Tif _ -> Misc.not_yet "conditional"
  | Tat _ -> Misc.not_yet "\\at"
  | Tbase_addr _ -> Misc.not_yet "\\base_addr"
  | Tblock_length _ -> Misc.not_yet "\\block_length"
  | Tnull -> mkCast (zero ~loc) (TPtr(TVoid [], [])), env, false
  | TCoerce _ -> Misc.not_yet "coercion"
  | TCoerceE _ -> Misc.not_yet "expression coercion"
  | TUpdate _ -> Misc.not_yet "functional update"
  | Ttypeof _ -> Misc.not_yet "typeof"
  | Ttype _ -> Misc.not_yet "C type"
  | Tempty_set -> Misc.not_yet "empty tset"
  | Tunion _ -> Misc.not_yet "union of tsets"
  | Tinter _ -> Misc.not_yet "intersection of tsets"
  | Tcomprehension _ -> Misc.not_yet "tset comprehension"
  | Trange _ -> Misc.not_yet "range"
  | Tlet _ -> Misc.not_yet "let binding"

(* Convert an ACSL term into a corresponding C expression (if any) in the given
   environment. Also extend this environment which includes the generating
   constructs. *)
and term_to_exp env ctx t = 
  let e, env, is_mpz_string = context_insensitive_term_to_exp env t in
  context_sensitive ~loc:t.term_loc env ctx is_mpz_string e

(* generate the C code equivalent to [t1 bop t2]. *)
and comparison_to_exp ?(loc=Location.unknown) ?e1 env bop t1 t2 =
  let ctx = match e1 with
    | None -> principal_type_from_term t1 t2 
    | Some(_, ctx) -> 
(*      Options.feedback "principality oriented by %a" d_logic_type ctx;*)
      principal_type_from_term { t1 with term_type = ctx } t2
  in
(*  Options.feedback "principal type of %a and %a is %a" 
    d_term t1 d_term t2 d_logic_type ctx;*)
  let e1, env = match e1 with
    | None -> term_to_exp env ctx t1
    | Some(e1, ctx1) when Cil_datatype.Logic_type.equal ctx ctx1 -> e1, env
    | Some(e1, _) -> context_sensitive ~loc:e1.eloc env ctx false e1
  in
  let e2, env = term_to_exp env ctx t2 in
  match ctx with
  | Linteger ->
    let e, env =
      Env.new_var
	env
	intType
	(fun v _ -> [ Misc.mk_call ~result:(var v) "mpz_cmp" [ e1; e2 ] ])
    in
    new_exp ?loc (BinOp(bop, e, zero ?loc, intType)), env
  | _ ->
    new_exp ?loc (BinOp(bop, e1, e2, intType)), env

(* Convert an ACSL named predicate into a corresponding C expression (if
   any) in the given environment. Also extend this environment which includes
   the generating constructs. *)
let rec named_predicate_to_exp env p = 
  let loc = p.loc in
  match p.content with
  | Pfalse -> zero ~loc, env
  | Ptrue -> one ~loc, env
  | Papp _ -> Misc.not_yet "logic function application"
  | Pseparated _ -> Misc.not_yet "separated"
  | Prel(rel, t1, t2) -> 
    let e, env = comparison_to_exp ~loc env (relation_to_binop rel) t1 t2 in
    context_sensitive ~loc env (Ctype intType) false e
  | Pand(p1, p2) ->
    (* p1 && p2 <==> if p1 then p2 else false *)
    let e1, env1 = named_predicate_to_exp env p1 in
    let e2, env2 = 
      named_predicate_to_exp (Env.no_overlap ~from:env1 Env.empty) p2 
    in
    let env = Env.merge_block_vars ~from:env2 env1 in
    Env.new_var
      env
      intType
      (fun v _ -> 
	let lv = var v in
	let then_block = 
	  let s = mkStmt ~valid_sid:true (Instr (Set(lv, e2, loc))) in
	  Env.block env2 s
	in
	let else_block = 
	  mkBlock [ mkStmt ~valid_sid:true (Instr (Set(lv, zero loc, loc))) ]
	in
	[ mkStmt ~valid_sid:true (If(e1, then_block, else_block, loc)) ])
  | Por(p1, p2) -> 
    (* p1 || p2 <==> if p1 then true else p2 *)
    let e1, env1 = named_predicate_to_exp env p1 in
    let e2, env2 = 
      named_predicate_to_exp (Env.no_overlap ~from:env1 Env.empty) p2 
    in
    let env = Env.merge_block_vars ~from:env2 env1 in
    Env.new_var
      env
      intType
      (fun v _ -> 
	let lv = var v in	
	let then_block = 
	  mkBlock [ mkStmt ~valid_sid:true (Instr (Set(lv, one loc, loc))) ]
	in
	let else_block = 
	  let s = mkStmt ~valid_sid:true (Instr (Set(lv, e2, loc))) in
	  Env.block env2 s
	in
	[ mkStmt ~valid_sid:true (If(e1, then_block, else_block, loc)) ])
  | Pxor _ -> Misc.not_yet "xor"
  | Pimplies(p1, p2) -> 
    named_predicate_to_exp env (Logic_const.por ((Logic_const.pnot p1), p2))
  | Piff _ -> Misc.not_yet "<==>"
  | Pnot p ->
    let e, env = named_predicate_to_exp env p in
    new_exp ~loc (UnOp(LNot, e, TInt(IInt, []))), env
  | Pif _ -> Misc.not_yet "_ ? _ : _"
  | Plet _ -> Misc.not_yet "let _ = _ in _"
  | Pforall _ -> Misc.not_yet "\\forall"
  | Pexists _ -> Misc.not_yet "\\exists"
  | Pat _ -> Misc.not_yet "\\at"
  | Pvalid _ -> Misc.not_yet "\\valid"
  | Pvalid_index _ -> Misc.not_yet "\\valid_index"
  | Pvalid_range _ -> Misc.not_yet "\\valid_range"
  | Pfresh _ -> Misc.not_yet "\\fresh"
  | Psubtype _ -> Misc.not_yet "subtyping relation"
  | Pinitialized _ -> Misc.not_yet "\\initialized"

(* ************************************************************************** *)
(* [convert_*] converts a given ACSL annotation into the corresponding C
   statement (if any) for runtime assertion checking *)
(* ************************************************************************** *)

let convert_preconditions env behaviors =
  let do_behavior env b = 
    let assumes_pred =
      List.fold_left
	(fun acc p -> Logic_const.pand (acc, Logic_const.unamed p.ip_content))
	Logic_const.ptrue
	b.b_assumes
    in
    List.fold_left
      (fun env p ->
	let p = 
	  Logic_const.pimplies (assumes_pred, Logic_const.unamed p.ip_content)
	in
	let e, env = named_predicate_to_exp env p in
	Env.add_stmt env (Misc.mk_e_acsl_guard ~reverse:true e p))
      env
      b.b_requires
  in 
  List.fold_left do_behavior env behaviors

let convert_postconditions env behaviors =
  (* generate one guard by postcondition of each behavior *)
  let do_behavior env b = 
    List.fold_left
      (fun env (t, p) ->
	match t with
	  | Normal -> 
	    let p = p.ip_content in
	    if p <> Ptrue && b.b_assumes <> [] then 
	      Misc.not_yet "assumes in conjunction with ensures in behaviors";
	    let p = Logic_const.unamed p in
	    let e, env = named_predicate_to_exp env p in
	    Env.add_stmt env (Misc.mk_e_acsl_guard ~reverse:true e p)
	  | Exits | Breaks | Continues | Returns ->
	    Misc.not_yet "abnormal termination case in behavior")
      env
      b.b_post_cond
  in 
  List.fold_left do_behavior env behaviors

let convert_behaviors env behaviors =
  List.iter
    (fun b ->
      if b.b_assigns <> WritesAny then 
	Misc.not_yet "assigns clause in behavior";
      if b.b_extended <> [] then Misc.not_yet "grammar extensions in behavior")
    behaviors;
  let pre_env = 
    convert_preconditions (Env.no_overlap ~from:env Env.empty) behaviors 
  in
  let post_env = 
    convert_postconditions (Env.no_overlap ~from:pre_env Env.empty) behaviors 
  in
  let env = Env.merge_function_vars ~from:pre_env env in
  let env = Env.merge_function_vars ~from:post_env env in
  Env.close_block_option pre_env, 
  Env.close_block_option post_env,
  env

let convert_spec env spec =
  if spec.spec_variant <> None then Misc.not_yet "variant clause";
  if spec.spec_terminates <> None then Misc.not_yet "terminates clause";
  if spec.spec_complete_behaviors <> [] then Misc.not_yet "complete behaviors";
  if spec.spec_disjoint_behaviors <> [] then Misc.not_yet "disjoint behaviors";
  convert_behaviors env spec.spec_behavior

let convert_named_predicate env p =
  let e, env = named_predicate_to_exp env p in
  assert (Typ.equal (typeOf e) intType);
  Env.add_stmt env (Misc.mk_e_acsl_guard ~reverse:true e p)

let convert_code_annotation env annot =
  try
    match annot.annot_content with
    | AAssert(l, p) -> 
      if l <> [] then Misc.not_yet "assertions applied only on some behaviors";
      convert_named_predicate env p, None
    | AStmtSpec(l, spec) ->
      if l <> [] then 
        Misc.not_yet "statement contract applied only on some behaviors";
      let pre_block, post_block, new_env =
	convert_spec env spec 
      in
      let env = Env.merge_function_vars ~from:new_env env in
      let env = match pre_block with
	| None -> env
	| Some b -> Env.add_stmt env (mkStmt ~valid_sid:true (Block b))
      in 
      env, post_block
    | AInvariant _ -> Misc.not_yet "invariant"
    | AVariant _ -> Misc.not_yet "variant"
    | AAssigns _ -> Misc.not_yet "assigns"
    | APragma _ -> Misc.not_yet "pragma"
  with Misc.Typing_error s ->
    let msg = Format.sprintf "invalid E-ACSL construct %s." s in
    if Options.Check.get () then Misc.type_error msg
    else Options.warning ~current:true "%s@\nignoring annotation." msg;
    env, None

(* ************************************************************************** *)
(* Visitor *)
(* ************************************************************************** *)

(* local reference to the below visitor and to [do_visit] *)
let first_global = ref true

(* the main visitor performing e-acsl checking and C code generator *)
class e_acsl_visitor prj generate = object (self)

  inherit Visitor.generic_frama_c_visitor
    prj
    ((if generate then copy_visit else inplace_visit) ())

  val mutable gen_vars = []
  val mutable pre_block = None
  val mutable post_block = None

  method vglob_aux g =
    if !first_global then begin
      first_global := false;
      ChangeDoChildrenPost([ g ], fun l -> Misc.e_acsl_header () :: l)
    end else
      DoChildren

  (* [TODO] handle integer constants in initializer
     BUT almost impossible without a main entry point *)
  (*  method vinit v off i = assert false *)

  method vvdec vi = 
    (* TODO: handle functions without code *)
    try
      let old_vi = get_original_varinfo self#behavior vi in
      let old_kf = Globals.Functions.get old_vi in
      let spec = 
	Visitor.visitFramacFunspec
	  (self :> Visitor.frama_c_visitor)
	  (Kernel_function.get_spec old_kf)
      in
      let pre_b, post_b, env = 
	Project.on prj (convert_spec Env.empty) spec
      in
      pre_block <- pre_b;
      post_block <- post_b;
      gen_vars <- Env.generated_function_variables env;
      DoChildren
    with Not_found ->
      DoChildren

  method vfunc f =
    let contract_vars = gen_vars in
    gen_vars <- [];
    let add_gen_vars f = 
      f.slocals <- contract_vars @ gen_vars @ f.slocals;
      gen_vars <- [];
      f
    in
    ChangeDoChildrenPost(f, add_gen_vars)

  method vstmt_aux stmt =
(*    Options.debug ~level:2 "proceeding stmt %d@." stmt.sid;*)
    (* [TODO] BUG HERE since the annotations tbl is the one of the old
       project. *)
    let env, post_stmts =
      Annotations.single_fold_stmt
	(fun (User old_a | AI(_, old_a)) (env, post_stmts) -> 
	  let a = 
	    Visitor.visitFramacCodeAnnotation
	      (self :> Visitor.frama_c_visitor)
	      old_a
	  in
	  let env, post_block = 
	    Project.on prj (convert_code_annotation env) a
	  in
	  let post_stmts = match post_block with
	    | None -> post_stmts
	    | Some b ->
              mkStmt ~valid_sid:true (Block b) :: post_stmts
	  in
	  env, post_stmts) 
	(get_original_stmt self#behavior stmt)
	(Env.empty, [])
    in
    (* verify internal invariants *)
    assert ((Env.is_empty env && post_stmts = []) 
	    || (not (Env.is_empty env) && generate));
    let mk_block stmt =
(*      Options.feedback "stmt %a: %a" d_stmt stmt Env.pretty env;*)
      gen_vars <- Env.generated_function_variables env @ gen_vars;
      let s = Env.block_as_stmt env stmt in
      let post_stmts = s :: post_stmts in
      let post_stmts = 
	let is_return s = match self#current_kf with
	  | None -> false
	  | Some old_kf -> 
	    let old_ret = 
	      try Kernel_function.find_return old_kf
	      with Kernel_function.No_Statement -> assert false
	    in
	    Stmt.equal s (get_stmt self#behavior old_ret)
	in
	if is_return stmt then
	  match post_block with
	  | None -> post_stmts
	  | Some b ->
	    (* that is the return stmt of a function with a postcondition *)
	    post_block <- None;
	    post_stmts @ [ mkStmt ~valid_sid:true (Block b) ]
	else
	  post_stmts
      in
      let stmts = match pre_block with
	| None -> post_stmts
	| Some b -> 
	  (* that is the first stmt of a function with a precondition *)
	  pre_block <- None;
	  mkStmt ~valid_sid:true (Block b) :: post_stmts
      in
      mkStmt ~valid_sid:true (Block (mkBlock stmts))
    in
    ChangeDoChildrenPost(stmt, mk_block)

  initializer Env.register_actions_queue self#get_filling_actions

end

let do_visit ?(prj=Project.current ()) generate =
  let vis = new e_acsl_visitor prj generate in
  first_global := true;
  (* explicit type annotation in order to check that no new method is introduced
     by error *)
  (vis : Visitor.frama_c_visitor)

(*
Local Variables:
compile-command: "make"
End:
*)
