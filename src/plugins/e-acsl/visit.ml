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

open Db_types
open Cil_types
open Cil

(* ************************************************************************** *)
(* General constructs *)
(* ************************************************************************** *)

let unknown_loc = Cil_datatype.Location.unknown

let new_lval v = new_exp ~loc:unknown_loc (Lval (var v))

let mk_call ?result fname args =
  (* the type is incorrect, but it doesn't matter *)
  let f = new_lval (makeGlobalVar fname voidType) in
  mkStmt ~valid_sid:true (Instr(Call(result, f, args, unknown_loc)))

exception Typing_error of string
let type_error s = raise (Typing_error s)

let not_yet s =
  Options.not_yet_implemented "construct `%s' is not yet supported" s

(* [TODO] should not generate the type if the user wants to link the resulting
   program with GMP: use an option for this purpose? *)
let e_acsl_header () = GText (Read_header.text ())

(* Build a C conditional doing a runtime assertion check. *)
let mk_if e p =
  let msg =
    let b = Buffer.create 97 in
    let fmt = Format.formatter_of_buffer b in
    let no_uni = Parameters.UseUnicode.get () in
    Parameters.UseUnicode.off ();
    Format.fprintf fmt "%a@?" Cil.d_predicate_named p;
    Parameters.UseUnicode.set no_uni;
    Buffer.contents b
  in
  let s = mk_call "e_acsl_fail" [ mkString unknown_loc msg ] in
  mkStmt ~valid_sid:true (If(e, mkBlock [ s ], mkBlock [], unknown_loc))

(* ************************************************************************** *)
(* GMP values *)
(* ************************************************************************** *)

module Mpz : sig
  val t_ty: typ (* type "mpz_t" *)
  val is_now_referenced: unit -> unit (* one variable "mpz_t" now exists *)
  val is_t: typ -> bool (* is the type equal to "mpz_t"? *)
  val init: varinfo -> stmt (* build stmt "mpz_init(v)" *)
  val clear: varinfo -> stmt (* build stmt "mpz_clear(v)" *)
  val set: varinfo -> exp -> stmt
(* build stmt "mpz_set_*(v, e)" with the good function 'set' according to the
   type of e *)
end = struct

  let t_torig =
  { torig_name = "mpz_t";
    tname = "mpz_t";
    ttype = TVoid [] (* incorrect but does not matter *);
    treferenced = false }

  let is_now_referenced () = t_torig.treferenced <- true

  let t_ty = TNamed(t_torig, [])
  let is_t ty = Cil_datatype.Typ.equal ty t_ty

  let apply_on_var funname v = mk_call ("mpz_" ^ funname) [ new_lval v ]
  let init = apply_on_var "init"
  let clear = apply_on_var "clear"

  let set v e =
    let fname, args = match typeOf e with
      | TInt((IBool | IChar | IUChar | IUInt | IUShort | IULong), _) ->
	"set_ui", [ e ]
      | TInt((ISChar | IShort | IInt | ILong), _) -> "set_si", [ e ]
      | TInt((ILongLong | IULongLong), _) -> assert false
      | TPtr(TInt(IChar, _), _) ->
	"set_str",
	(* decimal base for the number given as string *)
	[ e; integer ~loc:unknown_loc 10 ]
      | _ -> assert false
    in
    mk_call ("mpz_" ^ fname) (new_lval v :: args)

end

(* ************************************************************************** *)
(* Environments *)
(* ************************************************************************** *)

module New_vars: sig
  (* constant option: mpz_t constant associated to the varinfo at init time *)
  val push: typ -> exp option -> varinfo
  val finalize: unit -> (varinfo * exp option) list
end = struct

  (* the finalizer resets the counter in order to keep it small. However, Cil
     visitor is dummy: it believes that my counter is its own and thus change it
     to keep it stricly growing. Too bad! :-(

     Could be a real issue in practice since **many** variables are generated
     for E-ACSL (at least one variable by integer constant). *)

  let var_cpt = ref 0
  let vlist = ref []

  let push ty e =
    if Mpz.is_t ty then begin
      assert (e <> None);
      Mpz.is_now_referenced ()
    end else
      assert (e = None);
    incr var_cpt;
    let v =
      makeVarinfo
	~logic:false
	~generated:true
	false (* is a global ? *)
	false (* is a formal? *)
	("e_acsl_cst_" ^ string_of_int !var_cpt)
	ty
    in
    vlist := (v, e) :: !vlist;
    v

  let finalize () =
    var_cpt := 0;
    let l = !vlist in
    vlist := [];
    l

end

module New_block : sig
  val is_empty: unit -> bool
  val push: stmt -> unit
  val push_at_end: stmt -> unit
  val finalize: stmt -> block
end = struct

  let blist = ref []
  let slist = ref []

  let push s = blist := s :: !blist
  let push_at_end s = slist := s :: !slist

  let is_empty () = !blist = [] && !slist = []

  let finalize s =
    let l = !blist @ !slist @ [ s ] in
    blist := [];
    slist := [];
    mkBlock l

end

(* ************************************************************************** *)
(* Transforming terms and predicates into C expressions (if any) *)
(* ************************************************************************** *)

let constant_to_exp = function
  | CInt64(n, k, s) ->
    (match k with
    | IBool | IChar | IUChar | IUInt | IUShort | IULong ->
      kinteger64_repr ~loc:unknown_loc IULong n s
    | ISChar | IShort | IInt | ILong ->
      kinteger64_repr ~loc:unknown_loc ILong n s
    | ILongLong | IULongLong ->
      mkString ~loc:unknown_loc (Int64.to_string n))
  | CStr _ as c -> new_exp unknown_loc (Const c)
  | CWStr _ -> not_yet "wide character string constant"
  | CChr _ -> not_yet "character constant"
  | CReal _ -> not_yet "floating point constant"
  | CEnum _ -> not_yet "enum constant"

let tlval_to_lval = function
  | TVar { lv_origin = Some v }, TNoOffset -> Var v, NoOffset
  | _ -> not_yet "complex left value"

let rec nocheck_term_to_exp t = match t.term_node with
  | TConst c -> constant_to_exp c
  | TLval lv -> new_exp ~loc:unknown_loc (Lval (tlval_to_lval lv))
  | TSizeOf ty -> sizeOf ~loc:unknown_loc ty
  | TSizeOfE t ->
    let e = term_to_exp t in
    sizeOf ~loc:unknown_loc (typeOf e)
  | TSizeOfStr s -> new_exp ~loc:unknown_loc (SizeOfStr s)
  | TAlignOf ty -> new_exp ~loc:unknown_loc (AlignOf ty)
  | TAlignOfE t ->
    let e = term_to_exp t in
    new_exp ~loc:unknown_loc (AlignOfE e)
  | TUnOp _ -> not_yet "unary operator"
  | TBinOp _ -> not_yet "binary operator"
  | TCastE(ty, t) ->
    let e = term_to_exp t in
    mkCast e ty
  | TAddrOf lv -> mkAddrOf unknown_loc (tlval_to_lval lv)
  | TStartOf _ -> not_yet "beginning of an array"
  | Tapp _ -> not_yet "applying logic function"
  | Tlambda _ -> not_yet "functional"
  | TDataCons _ -> not_yet "constructor"
  | Tif _ -> not_yet "conditional"
  | Told _ -> not_yet "\\old"
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

and term_to_exp t = match t.term_type with
  | Ctype _ -> nocheck_term_to_exp t
  | Ltype _ -> not_yet "term from an user defined type"
  | Lvar _ -> not_yet "polymorphic term"
  | Linteger ->
    let e = nocheck_term_to_exp t in
    let v = New_vars.push Mpz.t_ty (Some e) in
    new_lval v
  | Lreal -> not_yet "real number"
  | Larrow _ -> not_yet "logic function"

let relation_to_revbinop = function
  | Rlt -> Ge
  | Rgt -> Le
  | Rle -> Gt
  | Rge -> Lt
  | Req -> Ne
  | Rneq -> Eq

(* convert an ACSL named predicate into the opposite C expression (if any).
   E.g. \true is converted into 0. *)
let rec named_predicate_to_revexp p = match p.content with
  | Pfalse -> one ~loc:unknown_loc
  | Ptrue -> zero ~loc:unknown_loc
  | Papp _ -> not_yet "logic function application"
  | Pseparated _ -> not_yet "separated"
  | Prel(rel, t1, t2) ->
    let bop = relation_to_revbinop rel in
    let e1 = term_to_exp t1 in
    let e2 = term_to_exp t2 in
    if Mpz.is_t (typeOf e1) then begin
      assert (Mpz.is_t (typeOf e2));
      let v = New_vars.push intType None in
      let result = var v in
      New_block.push (mk_call ~result "mpz_cmp" [ e1; e2 ]);
      let bop =
	BinOp(bop,
	      new_exp unknown_loc (Lval result),
	      zero unknown_loc,
	      intType)
      in
      new_exp unknown_loc bop
    end else
      new_exp unknown_loc (BinOp(bop, e1, e2, intType))
  | Pand _ -> not_yet "&&"
  | Por _ -> not_yet "||"
  | Pxor _ -> not_yet "xor"
  | Pimplies _ -> not_yet "==>"
  | Piff _ -> not_yet "<==>"
  | Pnot p ->
    let e = named_predicate_to_revexp p in
    new_exp unknown_loc (UnOp(Neg, e, TInt(IInt, [])))
  | Pif _ -> not_yet "_ ? _ : _"
  | Plet _ -> not_yet "let _ = _ in _"
  | Pforall _ -> not_yet "\\forall"
  | Pexists _ -> not_yet "\\exists"
  | Pold _ -> not_yet "\\old"
  | Pat _ -> not_yet "\\at"
  | Pvalid _ -> type_error "\\valid"
  | Pvalid_index _ -> type_error "\\valid_index"
  | Pvalid_range _ -> type_error "\\valid_range"
  | Pfresh _ -> not_yet "\\fresh"
  | Psubtype _ -> not_yet "subtyping relation"

(* ************************************************************************** *)
(* [convert_*] converts a given ACSL annotation into the corresponding C
   statement (if any) for runtime assertion checking *)
(* ************************************************************************** *)

let convert_named_predicate p =
  let e = named_predicate_to_revexp p in
  New_block.push_at_end (mk_if e p)

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
    if Options.Check.get () then raise (Typing_error msg)
    else Options.warning ~current:true "%s@\nignoring annotation." msg

let convert_rooted (User a | AI(_, a)) = convert_annotation a

(* ************************************************************************** *)
(* Visitor *)
(* ************************************************************************** *)

(* local reference to the below visitor and to [do_visit] *)
let first_global = ref true

(* the main visitor performing e-acsl checking and C code generator *)
class e_acsl_visitor prj generate = object

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
    (* new_block and new_vars is set by convert_before_after *)
    let is_empty_block = New_block.is_empty () in
    let new_vars = New_vars.finalize () in
    match is_empty_block, new_vars with
    | true, [] -> DoChildren
    | true, _ :: _ -> assert false
    | false, _ ->
      assert generate;
      let mk_block stmt =
	let b = New_block.finalize stmt in
	(* [TODO] efficiency could be improved *)
	gen_vars <-
	  List.fold_left
	  (fun acc (v, e) ->
	    b.blocals <- v :: b.blocals;
	    Extlib.may
	      (fun e ->
		let s1 = Mpz.init v in
		let s2 = Mpz.set v e in
		b.bstmts <- s1 :: s2 :: b.bstmts @ [ Mpz.clear v ])
	      e;
	    v :: acc)
	  []
	  new_vars;
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
