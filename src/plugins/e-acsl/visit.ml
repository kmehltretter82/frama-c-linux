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

(* handle leaves of AST terms *)
let wrap_leaf env e = function
  | Ctype _ -> e, env
  | Ltype _ -> Misc.not_yet "term from an user defined type"
  | Lvar _ -> Misc.not_yet "polymorphic term"
  | Linteger -> Env.new_var env Mpz.t (fun _ v -> [ Mpz.init_set v e ])
  | Lreal -> Misc.not_yet "real number"
  | Larrow _ -> Misc.not_yet "logic function"

let constant_to_exp ?(loc=Location.unknown) = function
  | CInt64(n, 
	   (IBool | IChar | IUChar | IUInt | IUShort | IULong
	       | ISChar | IShort | IInt | ILong as k), 
	   s) ->
    kinteger64_repr ?loc k n s
  | CInt64(n, (ILongLong | IULongLong), _s) -> 
    (* cannot use the string [s] (if any) since we do not know the base in which
       it is written. Such a base is required by GMP.
       [TODO] Actually possible to find the base for the string, but not done
       yet *)
    mkString ?loc (My_bigint.to_string n)
  | CStr _ | CWStr _ | CChr _ | CReal _ | CEnum _ as c -> 
    new_exp ?loc (Const c)

let rec thost_to_host env = function
  | TVar { lv_origin = Some v } -> Var v, env
  | TVar { lv_origin = None } -> Misc.not_yet "logic variable"
  | TResult _typ -> Misc.not_yet "\\result"
  | TMem t ->
    (* TODO: still untested *)
    let e, env = term_to_exp env t in
    Options.warning ~current:true ~once:true
      "missing guard for ensuring that %a is a valid memory access"
      d_term t;
    Mem e, env

and toffset_to_offset env = function
  | TNoOffset -> NoOffset, env
  | TField(f, offset) -> 
    (* TODO: still untested *)
    let offset, env = toffset_to_offset env offset in
    Field(f, offset), env
  | TIndex(t, offset) -> 
    let e, env = ptr_arith_term_to_exp env t in
    Options.warning ~current:true ~once:true
      "missing guard for ensuring that %a is a valid array index"
      d_term t;
    let offset, env = toffset_to_offset env offset in
    Index(e, offset), env

and tlval_to_lval env (host, offset) = 
  let host, env = thost_to_host env host in
  let offset, env = toffset_to_offset env offset in
  (host, offset), env

(* Convert an ACSL term into a corresponding C expression (if any) in the given
   environment. Also extend this environment which includes the generating
   constructs. *)
and term_to_exp env t = 
  let loc = t.term_loc in
  match t.term_node with
  | TConst c -> wrap_leaf env (constant_to_exp ~loc c) t.term_type
  | TLval lv -> 
    let lv, env = tlval_to_lval env lv in
    wrap_leaf env (new_exp ~loc (Lval lv)) t.term_type
  | TSizeOf ty -> sizeOf ~loc ty, env
  | TSizeOfE t ->
    let e, env = term_to_exp env t in
    sizeOf ~loc (typeOf e), env
  | TSizeOfStr s -> new_exp ~loc (SizeOfStr s), env
  | TAlignOf ty -> new_exp ~loc (AlignOf ty), env
  | TAlignOfE t ->
    let e, env = term_to_exp env t in
    new_exp ~loc (AlignOfE e), env
  | TUnOp(Neg | BNot as op, t) ->
    let e, env = term_to_exp env t in
    assert (Mpz.e_got_t e);
    let name = match op with
      | Neg -> "mpz_neg"
      | BNot -> "mpz_com"
      | LNot -> assert false
    in
    Env.new_var_and_mpz_init
      env (fun _ ev -> [ Misc.mk_call ~loc name [ ev; e ] ])
  | TUnOp(LNot, t) ->
    let e, env = term_to_exp env t in
    let ty = typeOf e in
    assert (not (Mpz.is_t ty));
    new_exp ~loc (UnOp(LNot, e, ty)), env
  | TBinOp(PlusA | MinusA | Mult | Div | Mod as bop, t1, t2) ->
    (* arithmetic binary operator *)
    let e1, env = term_to_exp env t1 in
    let e2, env = term_to_exp env t2 in
    assert (Typ.equal (typeOf e1) (typeOf e2));
    let name = name_of_mpz_arith_bop bop in
    (* guarding divisions and modulos *)
    let zero = Logic_const.tinteger 0 in
    let guard, env = match bop with
      | Div | Mod ->
	comparison_to_exp env Eq t2 zero
      | _ -> Exp.dummy, env
    in
    let mk_stmts _ e = 
      let call = Misc.mk_call ~loc name [ e; e1; e2 ]  in
      match bop with
      | Div | Mod ->
	let cond = 
	  Misc.mk_e_acsl_guard guard (Logic_const.prel (Req, t2, zero)) 
	in
	Env.add_assert cond (Logic_const.prel (Rneq, t2, zero));
	[ cond; call ]
      | _ ->
	[ call ]
    in
    Env.new_var_and_mpz_init env mk_stmts
  | TBinOp(Lt | Gt | Le | Ge | Eq | Ne as bop, t1, t2) ->
    (* comparison operators *)
    comparison_to_exp ~loc env bop t1 t2
  | TBinOp((Shiftlt | Shiftrt), _, _) ->
    (* left/right shift *)
    Misc.not_yet "left/right shift"
  | TBinOp((LOr | LAnd | BOr | BXor | BAnd), _, _) ->
    (* other logic/arith operators  *)
    Misc.not_yet "missing binary operator"
  | TBinOp(PlusPI | IndexPI | MinusPI | MinusPP as bop, t1, t2) ->
    (* binary operation over pointers *)
    (* [TODO] untested *)
    let e1, env = ptr_arith_term_to_exp env t1 in
    let e2, env = ptr_arith_term_to_exp env t2 in
    Options.warning ~current:true ~once:true
      "missing guard for ensuring that %a is a valid pointer"
      d_term t;
    (* the type of the result is the same than type of the pointer [e1],
       whatever is [e2] *)
    new_exp ~loc (BinOp(bop, e1, e2, typeOf e1)), env
  | TCastE(ty, t) ->
    (* [TODO] missing guard for ensuring no overflow when casting.
       Whether the guard should be emit depends on the subtyping relation. *)
    let e, env = term_to_exp env t in
    let e, env =
      if Mpz.e_got_t e then begin
	(* casting mpz_t to C type is unsafe: 
	   use dedicated gmp functions for coercions *)
	let name, ty = 
	  if isSignedInteger ty then "mpz_get_si", longType
	  else "mpz_get_ui", ulongType
	in
	Env.new_var
	  env
	  ty
	  (fun v _ -> [ Misc.mk_call ~loc ~result:(var v) name [ e ] ])
      end else 
	e, env
    in
    mkCast e ty, env
  | TAddrOf lv -> 
    let lv, env = tlval_to_lval env lv in
    mkAddrOf ~loc lv, env
  | TStartOf lv -> 
    let lv, env = tlval_to_lval env lv in
    mkAddrOrStartOf ~loc lv, env
  | Tapp _ -> Misc.not_yet "applying logic function"
  | Tlambda _ -> Misc.not_yet "functional"
  | TDataCons _ -> Misc.not_yet "constructor"
  | Tif _ -> Misc.not_yet "conditional"
  | Tat _ -> Misc.not_yet "\\at"
  | Tbase_addr _ -> Misc.not_yet "\\base_addr"
  | Tblock_length _ -> Misc.not_yet "\\block_length"
  | Tnull -> mkCast (zero ~loc) (TPtr(TVoid [], [])), env
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

and ptr_arith_term_to_exp env t = match t.term_type with
  | Linteger -> 
    (* add cast to prevent generation of mpz_t values for ptr arithmetics *)
    term_to_exp env (Logic_const.term (TCastE(intType, t)) (Ctype intType)) 
  | Ctype _ -> term_to_exp env t
  | Ltype _ | Lvar _ | Lreal | Larrow _ -> assert false

(* generate the C code equivalent to [t1 bop t2]. *)
and comparison_to_exp ?(loc=Location.unknown) env bop t1 t2 =
  let e1, env = term_to_exp env t1 in
  let e2, env = term_to_exp env t2 in
(*  Options.feedback "ty1=%a; ty2=%a" d_type (typeOf e1) d_type (typeOf e2);*)
  assert (Typ.equal (typeOf e1) (typeOf e2));
  if Mpz.e_got_t e1 then
    let e, env =
      Env.new_var
	env
	intType
	(fun v _ -> [ Misc.mk_call ~result:(var v) "mpz_cmp" [ e1; e2 ] ])
    in
    new_exp ?loc (BinOp(bop, e, zero ?loc, intType)), env
  else
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
    comparison_to_exp ~loc env (relation_to_binop rel) t1 t2
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
