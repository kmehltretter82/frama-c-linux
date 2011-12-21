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
  | PlusA -> "__gmpz_add"
  | MinusA -> "__gmpz_sub"
  | Mult -> "__gmpz_mul"
  | Div -> "__gmpz_tdiv_q"
  | Mod -> "__gmpz_tdiv_r"
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
  | TVar ({ lv_origin = None } as logic_v) -> 
    Var (Env.Logic_binding.get env logic_v), env
  | TResult _typ -> 
    let vis = Env.get_visitor env in
    let kf = Extlib.the vis#current_kf in
    let stmt = 
      try Kernel_function.find_return kf 
      with Kernel_function.No_Statement -> assert false
    in
    (match stmt.skind with
    | Return(Some { enode = Lval (lhost, NoOffset) }, _) -> lhost, env
    | _ -> assert false)
  | TMem t ->
    let e, env = term_to_exp env (Ctype intType) t in
    Options.warning ~source:(fst e.eloc) ~once:true
      "@[missing guard for ensuring that@ %a is a valid memory access@]"
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
      "@[missing guard for ensuring that@ %a is a valid array index@]"
      d_term t;
    let offset, env = toffset_to_offset env offset in
    Index(e, offset), env

and tlval_to_lval env (host, offset) = 
  let host, env = thost_to_host env host in
  let offset, env = toffset_to_offset env offset in
  (host, offset), env

(* the returned boolean says is the expression is an mpz_string *)
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
  | TUnOp(Neg | BNot as op, t') ->
    let e, env = term_to_exp env Linteger t' in
    let name = match op with
      | Neg -> "__gmpz_neg"
      | BNot -> "__gmpz_com"
      | LNot -> assert false
    in
    let e, env = 
      Env.new_var_and_mpz_init
	env
	(Some t)
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
    let e, env = Env.new_var_and_mpz_init env (Some t) mk_stmts in
    e, env, false
  | TBinOp(Div | Mod as bop, t1, t2) ->
    (* arithmetic binary operator potentially convertible into C *)
    let ctx = Typing.principal_type_from_term t1 t2 in
    let e1, env = term_to_exp env ctx t1 in
    let e2, env = term_to_exp env ctx t2 in
    (* guarding divisions and modulos *)
    let zero = Logic_const.tinteger ~ikind:IInt 0 in
    (* do not generate [e2] from [t2] twice *)
    let guard, env = comparison_to_exp env ~e1:(e2, ctx) Eq t2 zero (Some t) in
    let mk_stmts v e = 
      let name = name_of_mpz_arith_bop bop in
      let cond = 
	Misc.mk_e_acsl_guard guard (Logic_const.prel (Req, t2, zero)) 
      in
      Env.add_assert env cond (Logic_const.prel (Rneq, t2, zero));
      let instr = match ctx with
	| Ctype ty when isIntegralType ty -> 
	  let e = new_exp ~loc (BinOp(bop, e1, e2, ty)) in
	  mkStmtOneInstr ~valid_sid:true (Set((Var v, NoOffset), e, loc))
	| Linteger -> Misc.mk_call ~loc name [ e; e1; e2 ]
	| _ -> assert false
      in
      [ cond; instr ]
    in
    let t = Some t in
    let e, env = match ctx with
      | Ctype ty when isIntegralType ty -> Env.new_var env t ty mk_stmts 
      | Linteger -> Env.new_var_and_mpz_init env t mk_stmts
      | _ -> assert false
    in
    e, env, false
  | TBinOp(Lt | Gt | Le | Ge | Eq | Ne as bop, t1, t2) ->
    (* comparison operators *)
    let e, env = comparison_to_exp ~loc env bop t1 t2 (Some t) in
    e, env, false
  | TBinOp((Shiftlt | Shiftrt), _, _) ->
    (* left/right shift *)
    Error.not_yet "left/right shift"
  | TBinOp((LOr | LAnd | BOr | BXor | BAnd), _, _) ->
    (* other logic/arith operators  *)
    Error.not_yet "missing binary operator"
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
      "@[missing guard for ensuring that@ %a is a valid pointer@]"
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
  | Tapp _ -> Error.not_yet "applying logic function"
  | Tlambda _ -> Error.not_yet "functional"
  | TDataCons _ -> Error.not_yet "constructor"
  | Tif _ -> Error.not_yet "conditional"
  | Tat(t', label) ->
    let stmt = Env.stmt_of_label env label in
    let ty = t'.term_type in
    (* convert [t'] to [e] in a separated local env *)
    let e, env = term_to_exp (Env.push env) ty t' in
    let new_v = ref None in
    (* generate a new variable denoting [\at(t',label)].
       That is this variable which is the resulting expression. 
       ACSL typing rule ensures that the type of this variable is the same as
       the one of [e]. *)
    let res, new_env =
      Env.new_var ~global:true env
	(Some t) (typeOf e)
	(fun lv' e' -> 
	  (* store the corresponding left value and expression corresponding to
	     the new variable. Will be used in the visitor in order to
	     initialize it. *)
	  new_v := Some (lv', e'); [])
    in
    let env_ref = ref new_env in
      (* visitor modifying in place the labeled statement in order to store [e]
	 in the resulting variable at this location which is the only correct
	 one. *)
    let o = object 
      inherit Visitor.frama_c_inplace
      method vstmt_aux stmt = 
	let new_lv, new_e = Extlib.the !new_v in
	  (* either a standard C affectation or an mpz one according to type of
	     [e] *) 
	let new_stmt = Mpz.init_set (var new_lv) new_e e in
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
  | Tbase_addr _ -> Error.not_yet "\\base_addr"
  | Tblock_length _ -> Error.not_yet "\\block_length"
  | Tnull -> mkCast (zero ~loc) (TPtr(TVoid [], [])), env, false
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
  let e, env, is_mpz_string = context_insensitive_term_to_exp env t in
  Typing.context_sensitive ~loc:t.term_loc env ctx is_mpz_string (Some t) e

(* generate the C code equivalent to [t1 bop t2]. *)
and comparison_to_exp ?(loc=Location.unknown) ?e1 env bop t1 t2 t_opt =
  let ctx = match e1 with
    | None -> Typing.principal_type_from_term t1 t2 
    | Some(_, ctx) -> 
      (*      Options.feedback "principality oriented by %a" d_logic_type ctx;*)
      Typing.principal_type_from_term { t1 with term_type = ctx } t2
  in
  (*  Options.feedback "principal type of %a and %a is %a" 
      d_term t1 d_term t2 d_logic_type ctx;*)
  let e1, env = match e1 with
    | None -> term_to_exp env ctx t1
    | Some(e1, ctx1) when Cil_datatype.Logic_type.equal ctx ctx1 -> e1, env
    | Some(e1, _) -> 
      Typing.context_sensitive ~loc:e1.eloc env ctx false (Some t1) e1
  in
  let e2, env = term_to_exp env ctx t2 in
  match ctx with
  | Linteger ->
    let e, env =
      Env.new_var
	env
	t_opt
	intType
	(fun v _ -> [ Misc.mk_call ~result:(var v) "__gmpz_cmp" [ e1; e2 ] ])
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
  | Papp _ -> Error.not_yet "logic function application"
  | Pseparated _ -> Error.not_yet "separated"
  | Prel(rel, t1, t2) -> 
    let e, env = 
      comparison_to_exp ~loc env (relation_to_binop rel) t1 t2 None 
    in
    Typing.context_sensitive ~loc env (Ctype intType) false None e
  | Pand(p1, p2) ->
    (* p1 && p2 <==> if p1 then p2 else false *)
    let e1, env1 = named_predicate_to_exp env p1 in
    let e2, env2 = named_predicate_to_exp (Env.push env1) p2 in
    let env = Env.pop env2 in
    Env.new_var
      env
      None
      intType
      (fun v _ -> 
	let lv = var v in
	let then_block, _ = 
	  let s = mkStmtOneInstr ~valid_sid:true (Set(lv, e2, loc)) in
	  Env.pop_and_get env2 s ~global_clear:false Env.Middle
	in
	let else_block = 
	  mkBlock [ mkStmtOneInstr ~valid_sid:true (Set(lv, zero loc, loc)) ]
	in
	[ mkStmt ~valid_sid:true (If(e1, then_block, else_block, loc)) ])
  | Por(p1, p2) -> 
    (* p1 || p2 <==> if p1 then true else p2 *)
    let e1, env1 = named_predicate_to_exp env p1 in
    let e2, env2 = named_predicate_to_exp (Env.push env1) p2 in
    let env = Env.pop env2 in
    Env.new_var
      env
      None
      intType
      (fun v _ -> 
	let lv = var v in	
	let then_block = 
	  mkBlock [ mkStmt ~valid_sid:true (Instr (Set(lv, one loc, loc))) ]
	in
	let else_block, _ = 
	  let s = mkStmt ~valid_sid:true (Instr (Set(lv, e2, loc))) in
	  Env.pop_and_get env2 s ~global_clear:false Env.Middle
	in
	[ mkStmt ~valid_sid:true (If(e1, then_block, else_block, loc)) ])
  | Pxor _ -> Error.not_yet "xor"
  | Pimplies(p1, p2) -> 
    named_predicate_to_exp env (Logic_const.por ((Logic_const.pnot p1), p2))
  | Piff _ -> Error.not_yet "<==>"
  | Pnot p ->
    let e, env = named_predicate_to_exp env p in
    new_exp ~loc (UnOp(LNot, e, TInt(IInt, []))), env
  | Pif _ -> Error.not_yet "_ ? _ : _"
  | Plet _ -> Error.not_yet "let _ = _ in _"
  | Pforall(bounded_vars, { content = Pimplies(hyps, goal) }) -> 
    Quantif.convert env loc p bounded_vars hyps goal
  | Pforall _ -> Error.not_yet "unguarded \\forall quantification"
  (*  | Pexists(bounded_vars, { content = Pand(hyps, _goal) }) -> 
      let guards = compute_quantif_guards p bounded_vars hyps in
      List.iter 
      (fun (t1, _, x, _, t2) -> 
      Options.feedback
      "getting %a OP %a OP %a"  
      d_term t1 d_logic_var x d_term t2)
      guards;
      assert false*)
  | Pexists _ -> Error.not_yet "unguarded \\exists quantification"
  | Pat _ -> Error.not_yet "\\at"
  | Pvalid _ -> Error.not_yet "\\valid"
  | Pvalid_index _ -> Error.not_yet "\\valid_index"
  | Pvalid_range _ -> Error.not_yet "\\valid_range"
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
	if b.b_assigns <> WritesAny then 
	  Error.not_yet "assigns clause in behavior";
	if b.b_extended <> [] then 
	  Error.not_yet "grammar extensions in behavior";
	match t with
	  | Normal -> 
	    let p = p.ip_content in
	    if p <> Ptrue && b.b_assumes <> [] then 
	      Error.not_yet "assumes in conjunction with ensures in behaviors";
	    let p = Logic_const.unamed p in
	    let e, env = named_predicate_to_exp env p in
	    Env.add_stmt env (Misc.mk_e_acsl_guard ~reverse:true e p)
	  | Exits | Breaks | Continues | Returns ->
	    Error.not_yet "@[abnormal termination case in behavior@]")
      env
      b.b_post_cond
  in 
  List.fold_left do_behavior env behaviors

let convert_pre_spec env spec =
  let convert env =
    if spec.spec_variant <> None then Error.not_yet "variant clause";
    if spec.spec_terminates <> None then Error.not_yet "terminates clause";
    if spec.spec_complete_behaviors <> [] then 
      Error.not_yet "complete behaviors";
    if spec.spec_disjoint_behaviors <> [] then 
      Error.not_yet "disjoint behaviors";
    convert_preconditions env spec.spec_behavior
  in
  Error.handle convert env

let convert_post_spec env spec = 
  Error.handle (fun env -> convert_postconditions env spec.spec_behavior) env

let convert_named_predicate env p =
  let e, env = named_predicate_to_exp env p in
  assert (Typ.equal (typeOf e) intType);
  Env.add_stmt env (Misc.mk_e_acsl_guard ~reverse:true e p)

let convert_pre_code_annotation env annot =
  let convert env = match annot.annot_content with
    | AAssert(l, p) -> 
      if l <> [] then 
	Error.not_yet "@[assertions applied only on some behaviors@]";
      convert_named_predicate env p
    | AStmtSpec(l, spec) ->
      if l <> [] then 
        Error.not_yet "@[statement contract applied only on some behaviors@]";
      convert_pre_spec env spec ;
    | AInvariant _ -> Error.not_yet "invariant"
    | AVariant _ -> Error.not_yet "variant"
    | AAssigns _ -> Error.not_yet "assigns"
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
    | APragma _ -> env
  in
  Error.handle convert env

(* ************************************************************************** *)
(* Visitor *)
(* ************************************************************************** *)

(* local reference to the below visitor and to [do_visit] *)
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
    (* TODO: handle functions without code *)
    try
      let old_vi = get_original_varinfo self#behavior vi in
      let old_kf = Globals.Functions.get old_vi in
      funspec :=
	Cil.visitCilFunspec
	(self :> Cil.cilVisitor)
	(Kernel_function.get_spec old_kf);
      DoChildren
    with Not_found ->
      (* function without code *)
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
      Annotations.single_fold_stmt
	(fun (User old_a | AI(_, old_a)) (env, new_annots) -> 
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
	 Use [function_env] to store it. *)
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
	  mk_block b, env
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
