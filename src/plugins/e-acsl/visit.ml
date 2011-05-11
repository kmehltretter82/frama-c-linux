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

module New_vars: sig

  val push: typ -> (varinfo -> exp (* the var as exp *) -> stmt list) -> exp
  (* the closure as argument indicates how to initialize the given varinfo *)

  val push_and_mpz_init:
    (varinfo -> exp (* the var as exp *) -> stmt list) -> exp
  (* the closure as argument indicates how to initialize the given varinfo *)

  val finalize: unit -> (varinfo * exp * stmt list * bool) list
(* return the environment and reset it in order to be used again. 
   Each item of the returned list contains:
   - the generated varinfo
   - a C expression corresponding to this varinfo
   - a list of stmts initializing the varinfo to the right value
   - a boolean which is true iff the generated varinfo is a mpz_t variable. *)

end = struct

  (* the finalizer resets the counter in order to keep it small. However, Cil
     visitor is dummy: it believes that my counter is its own and thus change it
     to keep it stricly growing. Too bad! :-(

     Could be a real issue in practice since **many** variables are generated
     for E-ACSL (at least one variable by integer constant). *)

  let var_cpt = ref 0
  let vlist = ref []

  let push_list ty mk_stmts =
    incr var_cpt;
    let is_t = Mpz.is_t ty in
    if is_t then Mpz.is_now_referenced ();
    let v =
      makeVarinfo
	~logic:false
	~generated:true
	false (* is a global? *)
	false (* is a formal? *)
	("e_acsl_" ^ string_of_int !var_cpt)
	ty
    in
    let e = new_lval v in
    vlist := (v, e, mk_stmts v e, is_t) :: !vlist;
    e

  let push ty mk_stmts = push_list ty (fun v e -> mk_stmts v e)

  let push_and_mpz_init mk_stmts =
    push_list Mpz.t (fun v e -> Mpz.init e :: mk_stmts v e)

  let finalize () =
    var_cpt := 0;
    let l = !vlist in
    vlist := [];
    l

end

module New_block : sig
  val is_empty: unit -> bool
  val push: stmt -> unit
  val finalize: stmt -> block
end = struct

  let slist = ref []

  let push s = slist := s :: !slist
  let is_empty () = !slist = []

  let finalize s =
    let l = !slist @ [ s ] in
    slist := [];
    mkBlock l

end

module New_annotation : sig
  val push: stmt -> predicate named -> unit
  val finalize : (unit -> unit) Queue.t -> unit
end = struct
  let q = Queue.create ()
  let push s p = Queue.add (fun () -> Annotations.add_assert s [ !self ] p) q
  let finalize dest_q = Queue.transfer q dest_q
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

let relation_to_revbinop = function
  | Rlt -> Ge
  | Rgt -> Le
  | Rle -> Gt
  | Rge -> Lt
  | Req -> Ne
  | Rneq -> Eq

let name_of_mpz_arith_bop = function
  | PlusA -> "mpz_add"
  | MinusA -> "mpz_sub"
  | Mult -> "mpz_mul"
  | Div -> "mpz_cdiv_q"
  | Mod -> "mpz_mod"
  | Lt | Gt | Le | Ge | Eq | Ne | BAnd | BXor | BOr | LAnd | LOr
  | Shiftlt | Shiftrt | PlusPI | IndexPI | MinusPI | MinusPP -> assert false

let wrap_leaf e = function
  | Ctype _ -> e
  | Ltype _ -> not_yet "term from an user defined type"
  | Lvar _ -> not_yet "polymorphic term"
  | Linteger -> New_vars.push Mpz.t (fun _ v -> [ Mpz.init_set v e ])
  | Lreal -> not_yet "real number"
  | Larrow _ -> not_yet "logic function"

let rec term_to_exp t = 
  let loc = t.term_loc in
  match t.term_node with
  | TConst c -> wrap_leaf (constant_to_exp ~loc c) t.term_type
  | TLval lv -> wrap_leaf (new_exp ~loc (Lval (tlval_to_lval lv))) t.term_type
  | TSizeOf ty -> sizeOf ~loc ty
  | TSizeOfE t ->
    let e = term_to_exp t in
    sizeOf ~loc (typeOf e)
  | TSizeOfStr s -> new_exp ~loc (SizeOfStr s)
  | TAlignOf ty -> new_exp ~loc (AlignOf ty)
  | TAlignOfE t ->
    let e = term_to_exp t in
    new_exp ~loc (AlignOfE e)
  | TUnOp(Neg | BNot as op, t) ->
    let e = term_to_exp t in
    assert (Mpz.e_got_t e);
    let name = match op with
      | Neg -> "mpz_neg"
      | BNot -> "mpz_com"
      | LNot -> assert false
    in
    New_vars.push_and_mpz_init (fun _ ev -> [ mk_call ~loc name [ ev; e ] ])
  | TUnOp(LNot, t) ->
    let e = term_to_exp t in
    let ty = typeOf e in
    assert (not (Mpz.is_t ty));
    new_exp ~loc (UnOp(LNot, e, ty))
  | TBinOp(PlusA | MinusA | Mult | Div | Mod as bop, t1, t2) ->
    (* arithmetic binary operator *)
    let e1 = term_to_exp t1 in
    let e2 = term_to_exp t2 in
    assert (Cil_datatype.Typ.equal (typeOf e1) (typeOf e2));
    let name = name_of_mpz_arith_bop bop in
    (* guarding divisions and modulos *)
    let mk_stmts _ e = 
      let call = mk_call ~loc name [ e; e1; e2 ]  in
      match bop with
      | Div | Mod ->
	let z = Logic_const.tinteger 0 in
	let guard = comparison_to_exp Eq t2 z in
	let cond = mk_if guard (Logic_const.prel (Req, t2, z)) in
	New_annotation.push cond (Logic_const.prel (Rneq, t2, z));
	[ cond; call ]
      | _ ->
	[ call ]
    in
    New_vars.push_and_mpz_init mk_stmts
  | TBinOp(Lt | Gt | Le | Ge | Eq | Ne as bop, t1, t2) ->
    (* comparison operators *)
    comparison_to_exp ~loc bop t1 t2
  | TBinOp((Shiftlt | Shiftrt), _, _) ->
    (* left/right shift *)
    not_yet "left/right shift"
  | TBinOp((LOr | LAnd | BOr | BXor | BAnd), _, _) ->
    (* other logic/arith operators  *)
    not_yet "missing binary operator"
  | TBinOp(PlusPI | IndexPI | MinusPI | MinusPP as bop, t1, t2) ->
    (* binary operation over pointers *)
    (* [TODO] untested *)
    let e1 = term_to_exp t1 in
    let e2 = term_to_exp t2 in
    Options.warning ~current:true ~once:true
      "missing guard for ensuring that %a is a valid pointer"
      d_term t;
    (* the type of the result is the same than type of the pointer [e1],
       whatever is [e2] *)
    new_exp ~loc (BinOp(bop, e1, e2, typeOf e1))
  | TCastE(ty, t) ->
    (* [TODO] missing guard for ensuring no overflow when casting *)
    let e = term_to_exp t in
    mkCast e ty
  | TAddrOf lv -> mkAddrOf ~loc (tlval_to_lval lv)
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

and comparison_to_exp ?(loc=Location.unknown) bop t1 t2 =
  let e1 = term_to_exp t1 in
  let e2 = term_to_exp t2 in
(*  Options.feedback "ty1=%a; ty2=%a" d_type (typeOf e1) d_type (typeOf e2);*)
  assert (Cil_datatype.Typ.equal (typeOf e1) (typeOf e2));
  if Mpz.e_got_t e1 then
    let e =
      New_vars.push
	intType
	(fun v _ -> [ mk_call ~result:(var v) "mpz_cmp" [ e1; e2 ] ])
    in
    new_exp ?loc (BinOp(bop, e, zero ?loc, intType))
  else
    new_exp ?loc (BinOp(bop, e1, e2, intType))

(* convert an ACSL named predicate into the opposite C expression (if any).
   E.g. \true is converted into 0. *)
let rec named_predicate_to_revexp p = 
  let loc = p.loc in
  match p.content with
  | Pfalse -> one ~loc
  | Ptrue -> zero ~loc
  | Papp _ -> not_yet "logic function application"
  | Pseparated _ -> not_yet "separated"
  | Prel(rel, t1, t2) -> comparison_to_exp ~loc (relation_to_revbinop rel) t1 t2
  | Pand _ -> not_yet "&&"
  | Por _ -> not_yet "||"
  | Pxor _ -> not_yet "xor"
  | Pimplies _ -> not_yet "==>"
  | Piff _ -> not_yet "<==>"
  | Pnot p ->
    let e = named_predicate_to_revexp p in
    new_exp ~loc (UnOp(Neg, e, TInt(IInt, [])))
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

let convert_named_predicate p =
  let e = named_predicate_to_revexp p in
  New_block.push (mk_if e p)

let convert_annotation annot =
  try
    match annot.annot_content with
    | AAssert(_l, p) -> convert_named_predicate p
    | AStmtSpec _ -> not_yet "stmt spec"
    | AInvariant _ -> not_yet "invariant"
    | AVariant _ -> not_yet "variant"
    | AAssigns _ -> not_yet "assigns"
    | APragma _ -> not_yet "pragma"
  with Typing_error s ->
    let msg = Format.sprintf "invalid E-ACSL construct %s." s in
    if Options.Check.get () then type_error msg
    else Options.warning ~current:true "%s@\nignoring annotation." msg

let convert_rooted (User a | AI(_, a)) = convert_annotation a

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

  method vglob g =
    if !first_global then begin
      first_global := false;
      ChangeDoChildrenPost([ g ], fun l -> e_acsl_header () :: l)
    end else
      DoChildren

  (* [TODO] handle integer constants in initializer
     BUT almost impossible without a main entry point *)
  (*  method vinit v off i = assert false *)

  method vfundec f =
    let add_gen_vars f = f.slocals <- gen_vars @ f.slocals; f in
    ChangeDoChildrenPost(f, add_gen_vars)

  method vstmt_aux stmt =
(*    Options.debug ~level:2 "proceeding stmt %d@." stmt.sid;*)
    Annotations.single_iter_stmt (fun ba -> convert_rooted ba) stmt;
    (* new_block and new_vars is set by [convert_rooted] *)
    let is_empty_block = New_block.is_empty () in
    let new_vars = New_vars.finalize () in
    match is_empty_block, new_vars with
    | true, [] -> DoChildren
    | true, _ :: _ -> assert false
    | false, _ ->
      assert generate;
      let mk_block stmt =
	let b = New_block.finalize stmt in
	let vars, clears =
	  List.fold_left
	    (fun (vars, clears) (v, e, stmts, must_clear) ->
	      b.blocals <- v :: b.blocals;
	      b.bstmts <- stmts @ b.bstmts;
	      v :: vars, if must_clear then Mpz.clear e :: clears else clears)
	    ([], [])
	    new_vars
	in
	gen_vars <- vars;
	b.bstmts <- b.bstmts @ clears;
	New_annotation.finalize self#get_filling_actions;
	mkStmt ~valid_sid:true (Block b)
      in
      ChangeDoChildrenPost(stmt, mk_block)

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
