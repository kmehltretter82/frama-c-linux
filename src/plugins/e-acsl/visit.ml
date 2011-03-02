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

let unknown_loc = Cil_datatype.Location.unknown

exception Typing_error of string
let error s = raise (Typing_error s)
let not_yet s =
  Options.not_yet_implemented "construct `%s' is not yet supported" s

let e_acsl_header () =
 GText("/*@ terminates \\false;\n\
assigns \\nothing;\n\
ensures \\false; */\n\
extern void exit(int status);\n\
\n\
/*@ assigns \\nothing; */ \n\
extern void eprintf(char * ); \n\
\n\
void e_acsl_fail(char *msg) { eprintf(msg); exit(1); }")

(* Build a C conditional doing a runtime assertion check. *)
let mk_if acc e p =
  (* voidType is incorrect: will be resolved later *)
  let f =
    new_exp unknown_loc (Lval (var (makeGlobalVar "e_acsl_fail" voidType)))
  in
  let msg =
    let b = Buffer.create 97 in
    let fmt = Format.formatter_of_buffer b in
    Format.fprintf fmt "%a@?" Cil.d_predicate_named p;
    Buffer.contents b
  in
  let s = Instr(Call(None, f, [ mkString unknown_loc msg ], unknown_loc))in
  mkStmt(If(e, mkBlock [ mkStmt s ], mkBlock [], unknown_loc)) :: acc

(* ************************************************************************** *)
(* transforming terms and predicates into C expressions (if any) *)
(* ************************************************************************** *)

let constant_to_exp = function
  | CInt64 _ -> not_yet "integer"
  | CStr _ as c -> new_exp unknown_loc (Const c)
  | CWStr _ -> not_yet "wide character string constant"
  | CChr _ -> not_yet "character constant"
  | CReal _ -> not_yet "floating point constant"
  | CEnum _ -> not_yet "enum constant"

let rec term_to_exp t = match t.term_node with
  | TConst c -> constant_to_exp c
  | TLval _ -> not_yet "left value"
  | TSizeOf _ -> not_yet "sizeof"
  | TSizeOfE _ -> not_yet "sizeof(expr)"
  | TSizeOfStr _ -> not_yet "sizeof(string constant)"
  | TAlignOf _ -> not_yet "alignof"
  | TAlignOfE _ -> not_yet "alignof(expr)"
  | TUnOp _ -> not_yet "unary operator"
  | TBinOp _ -> not_yet "binary operator"
  | TCastE _ -> not_yet "cast"
  | TAddrOf _ -> not_yet "taking address"
  | TStartOf _ -> not_yet "beginning of an array"
  | Tapp _ -> not_yet "applying logic function"
  | Tlambda _ -> not_yet "functional"
  | TDataCons _ -> not_yet "constructor"
  | Tif _ -> not_yet "conditional"
  | Told _ -> not_yet "\\old"
  | Tat _ -> not_yet "\\at"
  | Tbase_addr _ -> not_yet "base address"
  | Tblock_length _ -> not_yet "block length"
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

(* untested *)
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
  | Prel(rel, t1, t2) -> (* untested *)
    let bop = relation_to_revbinop rel in
    let e1 = term_to_exp t1 in
    let e2 = term_to_exp t2 in
    new_exp unknown_loc (BinOp(bop, e1, e2, intType))
  | Pand _ -> not_yet "&&"
  | Por _ -> not_yet "||"
  | Pxor _ -> not_yet "xor"
  | Pimplies _ -> not_yet "==>"
  | Piff _ -> not_yet "<==>"
  | Pnot p -> named_predicate_to_revexp p
  | Pif _ -> not_yet "_ ? _ : _"
  | Plet _ -> not_yet "let _ = _ in _"
  | Pforall _ -> not_yet "\\forall"
  | Pexists _ -> not_yet "\\exists"
  | Pold _ -> not_yet "\\old"
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

let convert_named_predicate acc generate p =
  if generate then mk_if acc (named_predicate_to_revexp p) p else acc

let convert_annotation acc generate annot = match annot.annot_content with
  | AAssert(_l, p) -> convert_named_predicate acc generate p
  | AStmtSpec _ -> not_yet "stmt spec"
  | AInvariant _ -> not_yet "invariant"
  | AVariant _ -> not_yet "variant"
  | AAssigns _ -> not_yet "assigns"
  | APragma _ -> not_yet "pragma"

let convert_rooted acc generate (User a | AI(_, a)) =
  convert_annotation acc generate a

let convert_before_after acc generate (Before r | After r) =
  convert_rooted acc generate r

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

  method vglob g =
    if !first_global then begin
      first_global := false;
      ChangeDoChildrenPost([ g ], fun l -> e_acsl_header () :: l)
    end else
      DoChildren

  method vstmt_aux stmt =
    let l = Annotations.get_all_annotations stmt in
    match
      List.fold_right (fun ba acc -> convert_before_after acc generate ba) l []
    with
    | [] -> DoChildren
    | l ->
      assert generate;
      let mk_block stmt =
	mkStmt ~valid_sid:true (Block (mkBlock (l @ [ stmt ])))
      in
      ChangeDoChildrenPost(stmt, mk_block)

end

let do_visit ?(prj=Project.current ()) generate =
  let prj = new e_acsl_visitor prj generate in
  first_global := true;
  prj

(*
Local Variables:
compile-command: "make"
End:
*)
