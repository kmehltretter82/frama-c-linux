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

let self = ref State.dummy

(* ************************************************************************** *)
(* General constructs *)
(* ************************************************************************** *)

let new_lval ?(loc=Location.unknown) v = new_exp ~loc (Lval (var v))

let mk_call ?(loc=Location.unknown) ?result fname args =
  (* the type is incorrect, but it doesn't matter *)
  (* [JS 2011/04/12] should not generate a new variable by function name *) 
  let f = new_lval ~loc (makeGlobalVar fname voidType) in
  mkStmt ~valid_sid:true (Instr(Call(result, f, args, loc)))

exception Typing_error of string
let type_error s = raise (Typing_error s)

let not_yet s =
  Options.not_yet_implemented "construct `%s' is not yet supported." s

let e_acsl_header () = GText (Read_header.text ())

(* Build a C conditional doing a runtime assertion check. *)
let mk_if e p =
  let loc = p.loc in
  let unicode = Parameters.Unicode.get () in
  Parameters.Unicode.off ();
  let msg = Pretty_utils.sfprintf "%a@?" Cil.d_predicate_named p in
  Parameters.Unicode.set unicode;
  let s = mk_call ~loc "e_acsl_fail" [ mkString loc msg ] in
  mkStmt ~valid_sid:true (If(e, mkBlock [ s ], mkBlock [], loc))

(* ************************************************************************** *)
(* GMP values *)
(* ************************************************************************** *)

module Mpz : sig
  val t: typ (* type "mpz_t" *)
  val is_now_referenced: unit -> unit (* one variable "mpz_t" now exists *)
  val is_t: typ -> bool (* is the type equal to "mpz_t"? *)
  val e_got_t: exp -> bool (* is the type of e is equal to "mpz_t"? *)
  val init: exp -> stmt (* build stmt "mpz_init(v)" *)
  val clear: exp -> stmt (* build stmt "mpz_clear(v)" *)
  val init_set: exp -> exp -> stmt
(* build stmt "mpz_init_set_*(v, e)" with the good function 'set' according to
   the type of e *)
end = struct

  let t_torig =
  { torig_name = "mpz_t";
    tname = "mpz_t";
    ttype = TVoid [] (* incorrect but does not matter *);
    treferenced = false }

  let is_now_referenced () = t_torig.treferenced <- true

  let t = TNamed(t_torig, [])
  let is_t ty = Cil_datatype.Typ.equal ty t
  let e_got_t e = is_t (typeOf e)

  let apply_on_var funname e = mk_call ("mpz_" ^ funname) [ e ]
  let init = apply_on_var "init"
  let clear = apply_on_var "clear"

  let init_set v e =
    let fname, args = match typeOf e with
      | TInt((IBool | IChar | IUChar | IUInt | IUShort | IULong), _) ->
	"ui", [ e ]
      | TInt((ISChar | IShort | IInt | ILong), _) -> "si", [ e ]
      | TInt((ILongLong | IULongLong), _) -> assert false
      | TPtr(TInt(IChar, _), _) ->
	"str",
	(* decimal base for the number given as string *)
	[ e; integer ~loc:Location.unknown 10 ]
      | _ -> assert false
    in
    mk_call ("mpz_init_set_" ^ fname) (v :: args)

end

(* ************************************************************************** *)
(* Environments *)
(* ************************************************************************** *)

(* Environments handle all the new C constructs
   (variables, statements and annotations *)
module Env : sig
  type t
  val empty: t
  val new_var: 
    t -> typ -> (varinfo -> exp (* the var as exp *) -> stmt list) -> exp * t
  (* [new_var env ty mk_stmts] extends [env] with a fresh variable of type [ty].
     Return this variable as a C expression already initialized by applying it
     to [mk_stmts]. *)

  val new_var_and_mpz_init:
    t -> (varinfo -> exp (* the var as exp *) -> stmt list) -> exp * t
  (* Same as [new_var], but dedicated to mpz_t variables initialized by 
     {!Mpz.init}. *)

  val create_from: t -> t
  (* [create_from env] creates a fresh environment which does not overlap
     generated variables with [env]. *)

  val merge: from:t -> t -> t
  (* [merge ~from env] copies the generated variables of [from] to [env].
     Assume that there is no overlaping between [from] and [env]. *)

  val add_stmt: t -> stmt -> t
  (* [add_stmt env s] extends [env] with the new statement [s] *)

  val add_assert: stmt -> predicate named -> unit
  (* [add_assert s p] extends the global environment with an assertion [p]
     associated to the statement [s]. *)

  val register_actions_queue: (unit -> unit) Queue.t -> unit
  (* To be called once at initialization time: the queue of event of the
     visitor required for generating annotations. *)

  val generated_variables: t -> varinfo list
  (* All the new variables added in the environement *)

  val block : t -> stmt -> block
  (* [block env s] returns the block of statements including [s] and the new
     constructs of [env]. *)

  val is_empty: t -> bool
(* Is the given environment empty? *)

end = struct

  let queue = ref (Queue.create ())
  let register_actions_queue q = queue := q

  type t = 
      { var_cpt: int;
	vars: varinfo list;
	beginning_of_block: stmt list;
	end_of_block: stmt list }

  let empty = 
    { var_cpt = 0; vars = [] ; beginning_of_block = []; end_of_block = [] }

  let create_from env = 
    { var_cpt = env.var_cpt; 
      vars = env.vars; 
      beginning_of_block = [];
      end_of_block = [] }

  let merge ~from env = { env with var_cpt = from.var_cpt; vars = from.vars }

  let is_empty env = 
    if env.beginning_of_block = [] then begin
      assert (env.end_of_block = []);
      true
    end else
      false      

  let add_stmt env s = 
    { env with beginning_of_block = s :: env.beginning_of_block }

  let add_assert s p = 
    Queue.add (fun () -> Annotations.add_assert s [ !self ] p) !queue

  let new_var env ty mk_stmts = 
    let is_t = Mpz.is_t ty in
    if is_t then Mpz.is_now_referenced ();
    let n = succ env.var_cpt in
    let v =
      makeVarinfo
	~logic:false
	~generated:true
	false (* is a global? *)
	false (* is a formal? *)
	("e_acsl_" ^ string_of_int n)
	ty
    in
    let e = new_lval v in
    let stmts = mk_stmts v e in
    e,
    { var_cpt = n;
      vars = v :: env.vars;
      beginning_of_block = 
	List.fold_left (fun l s -> s :: l) env.beginning_of_block stmts;
      end_of_block = 
	if is_t then Mpz.clear e :: env.end_of_block else env.end_of_block }

  let new_var_and_mpz_init env mk_stmts = 
    new_var env Mpz.t (fun v e -> Mpz.init e :: mk_stmts v e)

  let generated_variables env = List.rev env.vars

  let block env s = 
    let b = 
      mkBlock 
	(List.rev env.beginning_of_block @ [ s ] @ List.rev env.end_of_block)
    in
    b.blocals <- b.blocals @ List.rev env.vars;
    b

end

(* ************************************************************************** *)
(* Transforming terms and predicates into C expressions (if any) *)
(* ************************************************************************** *)

let constant_to_exp ?(loc=Location.unknown) = function
  | CInt64(n, k, s) ->
    (match k with
    | IBool | IChar | IUChar | IUInt | IUShort | IULong
    | ISChar | IShort | IInt | ILong ->
      kinteger64_repr ?loc k n s
    | ILongLong | IULongLong ->
      mkString ?loc (Int64.to_string n))
  | CStr _ as c -> new_exp ?loc (Const c)
  | CWStr _ -> not_yet "wide character string constant"
  | CChr _ -> not_yet "character constant"
  | CReal _ -> not_yet "floating point constant"
  | CEnum _ -> not_yet "enum constant"

let tlval_to_lval = function
  | TVar { lv_origin = Some v }, TNoOffset -> Var v, NoOffset
  | _ -> not_yet "complex left value"

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
  | Ltype _ -> not_yet "term from an user defined type"
  | Lvar _ -> not_yet "polymorphic term"
  | Linteger -> Env.new_var env Mpz.t (fun _ v -> [ Mpz.init_set v e ])
  | Lreal -> not_yet "real number"
  | Larrow _ -> not_yet "logic function"

(* Convert an ACSL term into a corresponding C expression (if any) in the given
   environment. Also extend this environment which includes the generating
   constructs. *)
let rec term_to_exp env t = 
  let loc = t.term_loc in
  match t.term_node with
  | TConst c -> wrap_leaf env (constant_to_exp ~loc c) t.term_type
  | TLval lv -> 
    wrap_leaf env (new_exp ~loc (Lval (tlval_to_lval lv))) t.term_type
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
    Env.new_var_and_mpz_init env (fun _ ev -> [ mk_call ~loc name [ ev; e ] ])
  | TUnOp(LNot, t) ->
    let e, env = term_to_exp env t in
    let ty = typeOf e in
    assert (not (Mpz.is_t ty));
    new_exp ~loc (UnOp(LNot, e, ty)), env
  | TBinOp(PlusA | MinusA | Mult | Div | Mod as bop, t1, t2) ->
    (* arithmetic binary operator *)
    let e1, env = term_to_exp env t1 in
    let e2, env = term_to_exp env t2 in
    assert (Cil_datatype.Typ.equal (typeOf e1) (typeOf e2));
    let name = name_of_mpz_arith_bop bop in
    (* guarding divisions and modulos *)
    let zero = Logic_const.tinteger 0 in
    let guard, env = match bop with
      | Div | Mod ->
	comparison_to_exp env Eq t2 zero
      | _ -> Cil_datatype.Exp.dummy, env
    in
    let mk_stmts _ e = 
      let call = mk_call ~loc name [ e; e1; e2 ]  in
      match bop with
      | Div | Mod ->
	let cond = mk_if guard (Logic_const.prel (Req, t2, zero)) in
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
    not_yet "left/right shift"
  | TBinOp((LOr | LAnd | BOr | BXor | BAnd), _, _) ->
    (* other logic/arith operators  *)
    not_yet "missing binary operator"
  | TBinOp(PlusPI | IndexPI | MinusPI | MinusPP as bop, t1, t2) ->
    (* binary operation over pointers *)
    (* [TODO] untested *)
    let e1, env = term_to_exp env t1 in
    let e2, env = term_to_exp env t2 in
    Options.warning ~current:true ~once:true
      "missing guard for ensuring that %a is a valid pointer"
      d_term t;
    (* the type of the result is the same than type of the pointer [e1],
       whatever is [e2] *)
    new_exp ~loc (BinOp(bop, e1, e2, typeOf e1)), env
  | TCastE(ty, t) ->
    (* [TODO] missing guard for ensuring no overflow when casting *)
    let e, env = term_to_exp env t in
    mkCast e ty, env
  | TAddrOf lv -> mkAddrOf ~loc (tlval_to_lval lv), env
  | TStartOf _ -> not_yet "beginning of an array"
  | Tapp _ -> not_yet "applying logic function"
  | Tlambda _ -> not_yet "functional"
  | TDataCons _ -> not_yet "constructor"
  | Tif _ -> not_yet "conditional"
  | Tat _ -> not_yet "\\at"
  | Tbase_addr _ -> not_yet "\\base_addr"
  | Tblock_length _ -> not_yet "\\block_length"
  | Tnull -> not_yet "NULL"
  | TCoerce _ -> not_yet "coercion"
  | TCoerceE _ -> not_yet "expression coercion"
  | TUpdate _ -> not_yet "functional update"
  | Ttypeof _ -> not_yet "typeof"
  | Ttype _ -> not_yet "C type"
  | Tempty_set -> not_yet "empty tset"
  | Tunion _ -> not_yet "union of tsets"
  | Tinter _ -> not_yet "intersection of tsets"
  | Tcomprehension _ -> not_yet "tset comprehension"
  | Trange _ -> not_yet "range"
  | Tlet _ -> not_yet "let binding"

(* generate the C code equivalent to [t1 bop t2]. *)
and comparison_to_exp ?(loc=Location.unknown) env bop t1 t2 =
  let e1, env = term_to_exp env t1 in
  let e2, env = term_to_exp env t2 in
(*  Options.feedback "ty1=%a; ty2=%a" d_type (typeOf e1) d_type (typeOf e2);*)
  assert (Cil_datatype.Typ.equal (typeOf e1) (typeOf e2));
  if Mpz.e_got_t e1 then
    let e, env =
      Env.new_var
	env
	intType
	(fun v _ -> [ mk_call ~result:(var v) "mpz_cmp" [ e1; e2 ] ])
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
  | Papp _ -> not_yet "logic function application"
  | Pseparated _ -> not_yet "separated"
  | Prel(rel, t1, t2) -> 
    comparison_to_exp ~loc env (relation_to_binop rel) t1 t2
  | Pand(p1, p2) ->
    (* p1 && p2 <==> if p1 then p2 else false *)
    let e1, env1 = named_predicate_to_exp env p1 in
    let e2, env2 = named_predicate_to_exp (Env.create_from env1) p2 in
    let env = Env.merge ~from:env2 env1 in
    Env.new_var
      env
      intType
      (fun v _ -> 
	let lv = var v in
	let then_block = 
	  let s = mkStmt ~valid_sid:true (Instr (Set(lv, e2, loc))) in
	  if Env.is_empty env2 then mkBlock [ s ] else Env.block env2 s
	in
	let else_block = 
	  mkBlock [ mkStmt ~valid_sid:true (Instr (Set(lv, zero loc, loc))) ]
	in
	[ mkStmt ~valid_sid:true (If(e1, then_block, else_block, loc)) ])
  | Por(p1, p2) -> 
    (* p1 || p2 <==> if p1 then true else p2 *)
    let e1, env1 = named_predicate_to_exp env p1 in
    let e2, env2 = named_predicate_to_exp (Env.create_from env1) p2 in
    let env = Env.merge ~from:env2 env1 in
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
	  if Env.is_empty env2 then mkBlock [ s ] else Env.block env2 s
	in
	[ mkStmt ~valid_sid:true (If(e1, then_block, else_block, loc)) ])
  | Pxor _ -> not_yet "xor"
  | Pimplies(p1, p2) -> 
    named_predicate_to_exp env (Logic_const.por ((Logic_const.pnot p1), p2))
  | Piff _ -> not_yet "<==>"
  | Pnot p ->
    let e, env = named_predicate_to_exp env p in
    new_exp ~loc (UnOp(LNot, e, TInt(IInt, []))), env
  | Pif _ -> not_yet "_ ? _ : _"
  | Plet _ -> not_yet "let _ = _ in _"
  | Pforall _ -> not_yet "\\forall"
  | Pexists _ -> not_yet "\\exists"
  | Pat _ -> not_yet "\\at"
  | Pvalid _ -> not_yet "\\valid"
  | Pvalid_index _ -> not_yet "\\valid_index"
  | Pvalid_range _ -> not_yet "\\valid_range"
  | Pfresh _ -> not_yet "\\fresh"
  | Psubtype _ -> not_yet "subtyping relation"

(* ************************************************************************** *)
(* [convert_*] converts a given ACSL annotation into the corresponding C
   statement (if any) for runtime assertion checking *)
(* ************************************************************************** *)

let convert_named_predicate env p =
  let e, env = named_predicate_to_exp env p in
  assert (Typ.equal (typeOf e) intType);
  Env.add_stmt env (mk_if (new_exp ~loc:e.eloc (UnOp(LNot, e, intType))) p)

let convert_annotation env annot =
  try
    match annot.annot_content with
    | AAssert(_l, p) -> convert_named_predicate env p
    | AStmtSpec _ -> not_yet "stmt spec"
    | AInvariant _ -> not_yet "invariant"
    | AVariant _ -> not_yet "variant"
    | AAssigns _ -> not_yet "assigns"
    | APragma _ -> not_yet "pragma"
  with Typing_error s ->
    let msg = Format.sprintf "invalid E-ACSL construct %s." s in
    if Options.Check.get () then type_error msg
    else Options.warning ~current:true "%s@\nignoring annotation." msg;
    env

let convert_rooted env (User a | AI(_, a)) = convert_annotation env a

(* ************************************************************************** *)
(* Visitor *)
(* ************************************************************************** *)

(* local reference to the below visitor and to [do_visit] *)
let first_global = ref true

(* the main visitor performing e-acsl checking and C code generator *)
class e_acsl_visitor prj generate = object (self)

  inherit Visitor.generic_frama_c_visitor
    prj
    ((if generate then Cil.copy_visit else Cil.inplace_visit) ())

  val mutable gen_vars = []

  method vglob_aux g =
    if !first_global then begin
      first_global := false;
      ChangeDoChildrenPost([ g ], fun l -> e_acsl_header () :: l)
    end else
      DoChildren

  (* [TODO] handle integer constants in initializer
     BUT almost impossible without a main entry point *)
  (*  method vinit v off i = assert false *)

  method vvdec vi =
    try 
      let kf = Globals.Functions.get vi in
      let spec = Kernel_function.get_spec kf in
      if spec.spec_behavior <> [] then not_yet "behaviors clause of function";
      if spec.spec_variant <> None then not_yet "variant clause of function";
      if spec.spec_terminates <> None then
	not_yet "terminates clause of function";
      if spec.spec_complete_behaviors <> [] then 
	not_yet "complete behaviors of function";
      if spec.spec_disjoint_behaviors <> [] then 
	not_yet "disjoint behaviors of function";
      DoChildren
    with Not_found ->
      DoChildren

  method vfundec f =
    let add_gen_vars f = f.slocals <- gen_vars @ f.slocals; f in
    ChangeDoChildrenPost(f, add_gen_vars)

  method vstmt_aux stmt =
(*    Options.debug ~level:2 "proceeding stmt %d@." stmt.sid;*)
    let env =
      Annotations.single_fold_stmt
	(fun ba env -> convert_rooted env ba) 
	stmt 
	Env.empty
    in
    if Env.is_empty env then DoChildren
    else begin
      assert generate;
      let mk_block stmt =
	gen_vars <- Env.generated_variables env;
	mkStmt ~valid_sid:true (Block (Env.block env stmt))
      in
      ChangeDoChildrenPost(stmt, mk_block)
    end

  initializer Env.register_actions_queue self#get_filling_actions


end

let do_visit ?(prj=Project.current ()) generate =
  let vis = new e_acsl_visitor prj generate in
  first_global := true;
  (vis :> Visitor.frama_c_visitor)

(*
Local Variables:
compile-command: "make"
End:
*)
