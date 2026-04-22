(******************************************************************************)
(*                                                                            *)
(*  SPDX-License-Identifier LGPL-2.1                                          *)
(*  Copyright (C)                                                             *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)      *)
(*  INRIA (Institut National de Recherche en Informatique et en Automatique)  *)
(*                                                                            *)
(******************************************************************************)

open Cil_types

(** Smart constructors for the logic.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)

(** {1 Identification Numbers} *)

module AnnotId =
  State_builder.SharedCounter(struct let name = "annot_counter" end)
module PredicateId =
  State_builder.SharedCounter(struct let name = "predicate_counter" end)
module TermId =
  State_builder.SharedCounter(struct let name = "term_counter" end)
module ExtendedId =
  State_builder.SharedCounter(struct let name = "extended_counter" end)

let new_code_annotation annot =
  { annot_content = annot ; annot_id = AnnotId.next () }

let fresh_code_annotation = AnnotId.next

let toplevel_predicate ?(kind=Assert) p =
  { tp_kind = kind; tp_statement = p }

let new_predicate ?kind p =
  { ip_id = PredicateId.next (); ip_content = toplevel_predicate ?kind p }

let fresh_predicate_id = PredicateId.next

let pred_of_id_pred p = p.ip_content.tp_statement

let refresh_predicate p = { p with ip_id = PredicateId.next () }

let new_identified_term t =
  { it_id = TermId.next (); it_content = t }

let new_acsl_extension ~plugin:ext_plugin ext_name ext_loc ext_has_status ext_kind = {
  ext_id = ExtendedId.next ();
  ext_name;
  ext_plugin;
  ext_loc;
  ext_has_status;
  ext_kind
}

let fresh_term_id = TermId.next

let refresh_identified_term d = new_identified_term d.it_content

let refresh_identified_term_list = List.map refresh_identified_term

let refresh_deps = function
  | FromAny -> FromAny
  | From l ->
    From(refresh_identified_term_list l)

let refresh_from (a,d) = (new_identified_term a.it_content, refresh_deps d)

let refresh_allocation = function
  | FreeAllocAny -> FreeAllocAny
  | FreeAlloc(f,a) ->
    FreeAlloc((refresh_identified_term_list f),refresh_identified_term_list a)

let refresh_assigns = function
  | WritesAny -> WritesAny
  | Writes l ->
    Writes(List.map refresh_from l)

let refresh_behavior b =
  { b with
    b_requires = List.map refresh_predicate b.b_requires;
    b_assumes = List.map refresh_predicate b.b_assumes;
    b_post_cond =
      List.map (fun (k,p) -> (k, refresh_predicate p)) b.b_post_cond;
    b_assigns = refresh_assigns b.b_assigns;
    b_allocation = refresh_allocation b.b_allocation;
    (* no need to refresh b_extended, it contains only named predicates. *)
  }

let refresh_spec s =
  { spec_behavior = List.map refresh_behavior s.spec_behavior;
    spec_variant = s.spec_variant;
    spec_terminates = Option.map refresh_predicate s.spec_terminates;
    spec_complete_behaviors = s.spec_complete_behaviors;
    spec_disjoint_behaviors = s.spec_disjoint_behaviors;
  }

let refresh_code_annotation annot =
  let content =
    match annot.annot_content with
    | AAssert _ | AInvariant _ | AAllocation _ | AVariant _
    | AExtended _ as c -> c
    | AStmtSpec(l,spec) -> AStmtSpec(l, refresh_spec spec)
    | AAssigns(l,a) -> AAssigns(l, refresh_assigns a)

  in
  new_code_annotation content

(** {1 Smart constructors} *)

(** {2 pre-defined logic labels} *)
(* empty line for ocamldoc *)

let init_label = BuiltinLabel Init

let pre_label = BuiltinLabel Pre

let post_label = BuiltinLabel Post

let here_label = BuiltinLabel Here

let old_label = BuiltinLabel Old

let loop_current_label = BuiltinLabel LoopCurrent

let loop_entry_label = BuiltinLabel LoopEntry

(** {2 Types} *)

(** {2 Offsets} *)

let rec lastTermOffset (off: term_offset) : term_offset =
  match off with
  | TNoOffset | TField(_,TNoOffset) | TIndex(_,TNoOffset)
  | TModel(_,TNoOffset)-> off
  | TField(_,off) | TIndex(_,off) | TModel(_,off) -> lastTermOffset off

let rec addTermOffset (toadd: term_offset) (off: term_offset) : term_offset =
  match off with
  | TNoOffset -> toadd
  | TField(fid', offset) -> TField(fid', addTermOffset toadd offset)
  | TIndex(t, offset) -> TIndex(t, addTermOffset toadd offset)
  | TModel(m,offset) -> TModel(m,addTermOffset toadd offset)

let addTermOffsetLval toadd (b, off) : term_lval =
  b, addTermOffset toadd off


(** {2 Terms} *)
(* empty line for ocamldoc *)

(** @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)
let term ?(loc=Fileloc.unknown) term typ =
  { term_node = term;
    term_type = typ;
    term_name = [];
    term_loc = loc }

(** range of integers *)
let trange ?loc (low,high) =
  term ?loc (Trange(low,high))
    (Ltype(Logic_env.find_logic_type "set",[Linteger]))

let tboolean ?loc b =
  term ?loc (TConst (Boolean b)) Lboolean

(** An integer constant (of type integer). *)
let tinteger ?loc i =
  term ?loc (TConst (Integer (Z.of_int i,None))) Linteger

(** An integer constant (of type integer) from an int64 . *)
let tinteger_s64 ?loc i64 =
  term ?loc (TConst (Integer (Z.of_int64 i64,None))) Linteger

let tint ?loc i =
  term ?loc (TConst (Integer (i,None))) Linteger

(** A real constant (of type real) from a Caml float . *)
let treal ?loc f =
  let s = Pretty_utils.to_string Floating_point.pretty f in
  let r = { r_literal = s ; r_upper = f ; r_lower = f ; r_nearest = f ; } in
  term ?loc (TConst (LReal r)) Lreal

let treal_zero ?loc ?(ltyp=Lreal) () =
  let zero = { r_nearest = 0.0 ; r_upper = 0.0 ; r_lower = 0.0 ; r_literal = "0." } in
  term ?loc (TConst (LReal zero)) ltyp

let tstring ?loc s =
  (* Cannot refer to Cil_const.charConstPtrType in this module... *)
  let typ = Cil_const.(mk_tptr (mk_tint ~tattr:[("const", [])] IChar)) in
  term ?loc (TConst (LStr s)) (Ctype typ)

let tat ?loc (t,label) =
  term ?loc (Tat(t,label)) t.term_type

let told ?loc t = tat ?loc (t,old_label)

let tcast ?loc t ct =
  term ?loc (TCast(false, Ctype ct, t)) (Ctype ct)

let tlogic_coerce ?loc t lt =
  term ?loc (TCast (true, lt, t)) lt

let talignof ?loc ct =
  term ?loc (TAlignOf ct) Linteger

let tvar ?loc lv =
  term ?loc (TLval(TVar lv,TNoOffset)) lv.lv_type

let tresult ?loc typ =
  term ?loc (TLval(TResult typ,TNoOffset)) (Ctype typ)

(* needed by Cil, upon which Logic_utils depends.
   TODO: some refactoring of these two files *)
(** true if the given term is a lvalue denoting result or part of it *)
let rec is_result t = match t.term_node with
  | TLval (TResult _,_) -> true
  | Tat(t,_) -> is_result t
  | _ -> false

let rec is_exit_status t = match t.term_node with
  | TLval (TVar n,_) when n.lv_name = "\\exit_status" -> true
  | Tat(t,_) -> is_exit_status t
  | _ -> false

(** {2 Predicate constructors} *)
(* empty line for ocamldoc *)

let generated_loc =
  let p = Filepos.generated "kernel" in (p,p)

let pred ?(loc=generated_loc) ?(names=[]) p =
  { pred_content = p ; pred_loc = loc ; pred_name = names }

let unnamed ?loc p = pred ?loc p

let prepend_names ~names p = { p with pred_name = names @ p.pred_name }

let ptrue = unnamed Ptrue
let pfalse = unnamed Pfalse

let pold ?loc ?names p = match p.pred_content with
  | Ptrue | Pfalse -> p
  | _ -> pred ?loc ?names (Pat(p, old_label))

let papp ?loc ?names (p,lab,a) =
  pred ?loc ?names (Papp(p,lab,a))

let pand ?loc ?(names=[]) (p1, p2) =
  let p =
    match p1.pred_content, p2.pred_content with
    | Ptrue, _ -> p2
    | _, Ptrue -> p1
    | Pfalse, _ -> p1
    | _, Pfalse -> p2
    | _, _ -> unnamed ?loc (Pand (p1, p2))
  in
  prepend_names ~names p

let por ?loc ?(names=[]) (p1, p2) =
  let p =
    match p1.pred_content, p2.pred_content with
    | Ptrue, _ -> p1
    | _, Ptrue -> p2
    | Pfalse, _ -> p2
    | _, Pfalse -> p1
    | _, _ -> unnamed ?loc (Por (p1, p2))
  in
  prepend_names ~names p

let pxor ?loc ?(names=[]) (p1, p2) =
  let p =
    match p1.pred_content, p2.pred_content with
    | Ptrue, Ptrue -> unnamed ?loc Pfalse
    | Ptrue, _ -> p1
    | _, Ptrue -> p2
    | Pfalse, _ -> p2
    | _, Pfalse -> p1
    | _,_ -> unnamed ?loc (Pxor (p1,p2))
  in
  prepend_names ~names p

let pnot ?(loc=Fileloc.unknown) ?(names=[]) p2 =
  let p =
    match p2.pred_content with
    | Ptrue -> { p2 with pred_content = Pfalse; pred_loc = loc }
    | Pfalse ->  { p2 with pred_content = Ptrue; pred_loc = loc }
    | Pnot p -> p
    | _ -> unnamed ~loc (Pnot p2)
  in
  prepend_names ~names p

let pands ?(names=[]) l =
  let p = List.fold_right (fun p1 p2 -> pand (p1, p2)) l ptrue in
  prepend_names ~names p
let pors ?(names=[]) l =
  let p = List.fold_right (fun p1 p2 -> por (p1, p2)) l pfalse in
  prepend_names ~names p

let plet ?loc ?(names=[]) v p = match p.pred_content with
  | Ptrue -> prepend_names ~names p
  | _ -> pred ?loc ~names (Plet (v, p))

let pimplies ?(loc=Fileloc.unknown) ?(names=[]) (p1,p2) =
  let p =
    match p1.pred_content, p2.pred_content with
    | Ptrue, _ | _, Ptrue -> p2
    | Pfalse, _ -> { p1 with pred_loc = loc; pred_content = Ptrue }
    | _, _ -> unnamed ~loc (Pimplies (p1, p2))
  in
  prepend_names ~names p

let pif ?loc ?(names=[]) (c,p2,p3) =
  let p =
    match (p2.pred_content, p3.pred_content) with
    | Ptrue, Ptrue  -> ptrue
    | Pfalse, Pfalse -> pfalse
    | _,_ -> unnamed ?loc (Pif (c,p2,p3))
  in
  prepend_names ~names p

let piff ?loc ?(names=[]) (p2,p3) =
  let p =
    match p2.pred_content, p3.pred_content with
    | Pfalse, Pfalse -> ptrue
    | Ptrue, _  -> p3
    | _, Ptrue -> p2
    | _,_ -> unnamed ?loc (Piff (p2,p3))
  in
  prepend_names ~names p

(** @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)
let prel ?loc ?names (a,b,c) =
  pred ?loc ?names (Prel(a,b,c))

let pforall ?loc ?(names=[]) (l,p) =
  let p =
    match l with
    | [] -> p
    | _ :: _ ->
      match p.pred_content with
      | Ptrue -> p
      | _ -> unnamed ?loc (Pforall (l,p))
  in
  prepend_names ~names p

let pexists ?loc ?(names=[]) (l,p) =
  let p =
    match l with
    | [] -> p
    | _ :: _ -> match p.pred_content with
      | Pfalse -> p
      | _ -> unnamed ?loc (Pexists (l,p))
  in
  prepend_names ~names p

let pfresh ?loc ?names (l1,l2,p,n) = pred ?loc ?names (Pfresh (l1,l2,p,n))
let pallocable ?loc ?names (l,p) = pred ?loc ?names (Pallocable (l,p))
let pfreeable ?loc ?names (l,p) = pred ?loc ?names (Pfreeable (l,p))
let pvalid ?loc ?names (l,p) = pred ?loc ?names (Pvalid (l,p))
let pvalid_read ?loc ?names (l,p) = pred ?loc ?names (Pvalid_read (l,p))
let pobject_pointer ?loc ?names (l,p) = pred ?loc ?names (Pobject_pointer (l,p))
let pvalid_function ?loc ?names p = pred ?loc ?names (Pvalid_function p)

(* the index should be an integer or a range of integers *)
let pvalid_index ?loc ?names (l,t1,t2) =
  let ty1 = t1.term_type in
  let ty2 = t2.term_type in
  let t, ty =(match t1.term_node with
      | TStartOf lv ->
        TAddrOf (addTermOffsetLval (TIndex(t2,TNoOffset)) lv)
      | _ -> TBinOp (PlusPI, t1, t2)),
             Ast_types.Acsl.set_conversion ty1 ty2 in
  let t = term ?loc t ty in
  pvalid ?loc ?names (l,t)
(* the range should be a range of integers *)
let pvalid_range ?loc ?names (l,t1,b1,b2) =
  let t2 = trange ((Some b1), (Some b2)) in
  pvalid_index ?loc ?names (l,t1,t2)
let pat ?loc ?names (p,q) = pred ?loc ?names (Pat (p,q))
let pinitialized ?loc ?names (l,p) =
  pred ?loc ?names (Pinitialized (l,p))
let pdangling ?loc ?names (l,p) =
  pred ?loc ?names (Pdangling (l,p))

let pseparated ?loc ?names seps =
  pred ?loc ?names (Pseparated seps)

let paligned ?loc ?names (p, n) =
  pred ?loc ?names (Paligned(p, n))




let instantiate = Ast_types.Acsl.instantiate

let is_unrollable_ltdef = Ast_types.Acsl.is_unrollable_ltdef

let unroll_ltdef = Ast_types.Acsl.unroll_ltdef

let isLogicCType = Ast_types.Acsl.is_plain_ctype

let is_list_type = Ast_types.Acsl.is_plain_list

(** build the type list of [ty]. *)
let make_type_list_of = Ast_types.Acsl.make_list

(** returns the type of elements of a list type.
    @raise Failure if the input type is not a list type. *)
let type_of_list_elem = Ast_types.Acsl.list_element

let is_set_type = Ast_types.Acsl.is_plain_set

let set_conversion = Ast_types.Acsl.set_conversion

let make_set_type = Ast_types.Acsl.make_set

let type_of_element = Ast_types.Acsl.set_element

let plain_or_set = Ast_types.Acsl.plain_or_set

let transform_element = Ast_types.Acsl.transform_element

let is_plain_type = Ast_types.Acsl.is_plain

let make_arrow_type = Ast_types.Acsl.make_arrow

let is_boolean_type = Ast_types.Acsl.is_logic_bool
