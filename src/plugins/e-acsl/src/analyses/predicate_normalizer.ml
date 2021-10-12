(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

type pred_or_term = Lscope.pred_or_term

module Id_predicate =
  Datatype.Make_with_collections
    (struct
      include Cil_datatype.Predicate
      let name = "E_ACSL.Id_predicate"
      (* The function compare should never be used since we only use this
         datatype for hashtables *)
      let compare _ _ = assert false
      let equal (p1:predicate) p2 = p1 == p2
      let structural_descr = Structural_descr.t_abstract
      let hash = Logic_utils.hash_predicate
      let rehash = Datatype.identity
      let mem_project = Datatype.never_any_project
    end)

(* Memoization module which retrieves the preprocessed form of predicates *)
module Memo: sig
  val memo_pred: (predicate -> pred_or_term option) -> predicate -> unit
  val get_pred: predicate -> pred_or_term
  val memo_term : (term -> term option) -> term -> unit
  val get_term : term -> term
  val clear: unit -> unit
end = struct

  let tbl_term = Misc.Id_term.Hashtbl.create 97
  let tbl_pred = Id_predicate.Hashtbl.create 97

  let get_pred p =
    try Id_predicate.Hashtbl.find tbl_pred p
    with Not_found -> Lscope.PoT_pred p

  let memo_pred process p =
    try ignore (Id_predicate.Hashtbl.find tbl_pred p) with
    | Not_found ->
      match process p with
      | Some pot -> Id_predicate.Hashtbl.add tbl_pred p pot
      | None -> ()

  let get_term t =
    try Misc.Id_term.Hashtbl.find tbl_term t
    with Not_found -> t

  let memo_term process t =
    try ignore (Misc.Id_term.Hashtbl.find tbl_term t) with
    | Not_found ->
      match process t with
      | Some term -> Misc.Id_term.Hashtbl.add tbl_term t term
      | None -> ()

  let clear () =
    Misc.Id_term.Hashtbl.clear tbl_term;
    Id_predicate.Hashtbl.clear tbl_pred

end

let preprocess_pred ~loc p =
  match p.pred_content with
  | Pvalid_read(BuiltinLabel Here as llabel, t)
  | Pvalid(BuiltinLabel Here as llabel, t) -> begin
      match t.term_node, t.term_type with
      | TLval tlv, lty ->
        let init =
          Logic_const.pinitialized
            ~loc
            (llabel, Logic_utils.mk_logic_AddrOf ~loc tlv lty)
        in
        (* need to store a copy, to avoid p to appear in its own preprocessed form (otherwise it loops) *)
        let p_copy =
          match p.pred_content with
          | Pvalid_read _ -> Logic_const.pvalid_read ~loc (llabel, t)
          | Pvalid _ -> Logic_const.pvalid ~loc (llabel, t)
          | _ -> assert false
        in
        Some (Lscope.PoT_pred (Logic_const.pand ~loc (init, p_copy)))
      | _ -> None
    end
  | Papp(li, labels, args) ->
    (* Simply use the implementation of Tapp(li, labels, args). To achieve this,
       we create a clone of [li] for which the type is transformed from [None]
       (type of predicates) to [Some boolean] (typed as a term). *)
    let prj = Project.current () in
    let o = object inherit Visitor.frama_c_copy prj end in
    let li = Visitor.visitFramacLogicInfo o li in
    let lty = Logic_const.boolean_type in
    li.l_type <- Some lty;
    let tapp = Logic_const.term ~loc (Tapp(li, labels, args)) lty in
    Some (Lscope.PoT_term tapp)
  | _ -> None

let preprocess_term ~loc t =
  match t.term_node with
  | Tapp(li, lst, [ t1; t2; {term_node = Tlambda([ k ], predicate)}])
    when li.l_body = LBnone && li.l_var_info.lv_name = "\\numof" ->
    let logic_info = Cil_const.make_logic_info "\\sum" in
    logic_info.l_type <- li.l_type;
    logic_info.l_tparams <- li.l_tparams;
    logic_info.l_labels <- li.l_labels;
    logic_info.l_profile <- li.l_profile;
    logic_info.l_body <- li.l_body;
    let conditional_term =
      Logic_const.term ~loc
        (Tif(predicate, Cil.lone (), Cil.lzero ())) Linteger
    in
    let lambda_term =
      Logic_const.term ~loc (Tlambda([ k ], conditional_term)) Linteger
    in
    Some (Logic_const.term ~loc
            (Tapp(logic_info, lst, [ t1; t2; lambda_term ])) Linteger)
  | _ -> None


let preprocessor = object
  inherit Visitor.frama_c_inplace

  (* Only logic functions and logic predicates are handled.
     E-acsl simply ignores all the other global annotations *)
  method !vannotation annot =
    match annot with
    | Dfun_or_pred _ -> Cil.DoChildren
    | _ -> Cil.SkipChildren

  (* Ignore the annotations attached to statements from the RTL *)
  method !vglob_aux =
    function
    | g when Rtl.Symbols.mem_global g ->
      Cil.SkipChildren

    | GFun({ svar = vi }, _) when Builtins.mem vi.vname ->
      Cil.SkipChildren

    | GFun({ svar = vi }, _)
      when Misc.is_fc_or_compiler_builtin vi ->
      Cil.SkipChildren

    | GFun({svar = vi}, _) ->
      let kf = try Globals.Functions.get vi with Not_found -> assert false in
      if Functions.check kf then Cil.DoChildren else Cil.SkipChildren

    | GAnnot _ -> Cil.DoChildren

    (* other globals: nothing to do *)
    | GFunDecl _
    | GVarDecl _
    | GVar _
    | GType _
    | GCompTag _
    | GCompTagDecl _
    | GEnumTag _
    | GEnumTagDecl _
    | GAsm _
    | GPragma _
    | GText _
      -> Cil.SkipChildren

  method !vpredicate p =
    let loc = p.pred_loc in
    Memo.memo_pred (preprocess_pred ~loc) p;
    Cil.DoChildren

  method !vterm t =
    let loc = t.term_loc in
    Memo.memo_term (preprocess_term ~loc) t;
    Cil.DoChildren
end

let preprocess ast =
  Visitor.visitFramacFileSameGlobals preprocessor ast

let preprocess_annot annot =
  ignore (Visitor.visitFramacCodeAnnotation preprocessor annot)

let preprocess_predicate p =
  ignore (Visitor.visitFramacPredicate preprocessor p)

let get_pred = Memo.get_pred
let get_term = Memo.get_term
let clear = Memo.clear
