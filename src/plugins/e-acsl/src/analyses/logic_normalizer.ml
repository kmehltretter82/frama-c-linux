(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2024                                               *)
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

let dkey = Options.Dkey.logic_normalizer

module Id_predicate =
  Datatype.Make_with_collections
    (struct
      include Predicate
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

module BiMap (H : Hashtbl.S) = struct
  let from_tbl = H.create 7
  let dest_tbl = H.create 7

  let clear () =
    H.clear from_tbl;
    H.clear dest_tbl

  let add from dest =
    H.add from_tbl from dest;
    H.add dest_tbl dest from

  let dest from = H.find from_tbl from
  let dest_opt from = H.find_opt from_tbl from
  let from dest = H.find dest_tbl dest
  let from_opt dest = H.find_opt dest_tbl dest

  let dest_or_self from = try dest from with Not_found -> from
  let from_or_self dest = try from dest with Not_found -> dest
end

(* Memoization modules for retrieving the preprocessed and original form of
   predicates and terms *)
module Memo (H : Hashtbl.S) = struct
  module M = BiMap (H)

  let clear = M.clear

  let normalized x = M.dest_or_self x
  let normalized_opt x = M.dest_opt x
  let original x = M.from_or_self x
  let original_opt x = M.from_opt x

  let memoize process x =
    try Some (M.dest x) with
    | Not_found ->
      match process x with
      | Some y -> M.add x y; Some y
      | None -> None
end

module Predicates = Memo (Id_predicate.Hashtbl)
module Terms = Memo (Misc.Id_term.Hashtbl)
module Here_specialized = Memo (Logic_info.Hashtbl)

let pp_logic_info fmt li =
  Printer.pp_global_annotation fmt (Dfun_or_pred (li, Location.unknown))

module Logic_infos : sig
  val origin_of_lv : logic_var -> logic_var
  val generated_of : logic_info -> logic_info list
end = struct
  let original_of_lv lv =
    Here_specialized.original_opt
      {l_var_info = lv;
       l_labels = [];
       l_tparams = [];
       l_type = None;
       l_profile = [];
       l_body = LBnone}

  let rec origin_of_lv lv =
    match original_of_lv lv with
    | None -> lv
    | Some origin -> origin_of_lv origin.l_var_info

  let generated_of li = Option.to_list @@ Here_specialized.normalized_opt li
end

(** E-ACSL currently is not in general capable of translationg predicates and
    logic functions with labels. However often such functions are used
    while supplying the Here label.
    In this case we can specialize the logic function, such that it has no
    labels, substituting all occurrences of the original labels by the Here
    label. Then the specialized function can be used instead of the original
    one whenever all labels are Here. *)
module Here_inliner : sig
  val preprocess_pred : predicate -> predicate option
  val preprocess_term : term -> term option

  (** apply a preprocessor to the result of another *)
  val bind : ('a -> 'a option) -> 'a -> 'a option -> 'a option
end = struct

  let here = BuiltinLabel Here
  let is_here = (=) here
  let are_all_here labels = List.length labels > 0 && List.for_all is_here labels

  (** substitute occurrences of li_old by li_new; also substitute occurrences
      of li_old's formal parameters by li_new's parameters; li_new does not
      have any labels so substitute occurrences of li_old's labels by Here *)
  let substitute li_old li_new =
    let formal_substitutions =
      Logic_var.Map.of_seq
        (List.to_seq @@ List.combine li_old.l_profile li_new.l_profile)
    in
    let is_obsolete_label =
      let obsolete_labels =
        Logic_label.Set.of_seq @@ List.to_seq @@ here :: li_old.l_labels
      in
      fun l -> Logic_label.Set.mem l obsolete_labels
    in
    object
      inherit Visitor.frama_c_inplace

      method! vlogic_var_use lv =
        match Logic_var.Map.find_opt lv formal_substitutions with
        | None -> DoChildren
        | Some lv' -> ChangeTo lv'

      method !vpredicate p =
        match p.pred_content with
        | Papp (li, labels, args) when
            Logic_info.equal li li_old && List.for_all is_obsolete_label labels ->
          let p = {p with pred_content = Papp (li_new, [], args)} in
          ChangeDoChildrenPost (p, fun x -> x)
        | _ -> DoChildren

      method !vterm t =
        match t.term_node with
        | Tat (body, label) when is_obsolete_label label ->
          ChangeDoChildrenPost (body, fun x -> x)
        | Tapp (li, labels, args) when
            Logic_info.equal li li_old && List.for_all is_obsolete_label labels ->
          let t = {t with term_node = Tapp (li_new, [], args)} in
          ChangeDoChildrenPost (t, fun x -> x)
        | _ -> DoChildren

      method !vlogic_info_use l =
        if Logic_info.equal l li_old
        then ChangeTo li_new
        else DoChildren

      method !vlogic_label l =
        if is_obsolete_label l then ChangeTo here else DoChildren
    end

  let specialize li =
    let f li =
      let lv_name = Functions.RTL.mk_gen_name (li.l_var_info.lv_name ^ "_here") in
      let vi = {li.l_var_info with lv_name; lv_id = Cil_const.new_raw_id ()} in
      let li' = {
        li with
        l_var_info = vi;
        l_labels = [];
        l_profile =
          List.map (fun lv -> {lv with lv_id = Cil_const.new_raw_id ()}) li.l_profile
      } in
      let li' = Visitor.visitFramacLogicInfo (substitute li li') li' in
      let pred_or_term =
        match li.l_type with None -> "predicate" | Some _ -> "logic function"
      in
      Options.feedback ~dkey ~level:2
        "specializing %s %a for use cases using the Here label"
        pred_or_term
        Printer.pp_logic_info li;
      Options.feedback ~dkey ~level:3
        "specialized version of %s %a:@ @[%a@]"
        pred_or_term
        Printer.pp_logic_info li
        pp_logic_info li';
      Some li'
    in
    Option.get @@ Here_specialized.memoize f li

  let inliner = object (self)
    inherit Visitor.frama_c_inplace

    method !vpredicate p =
      match p.pred_content with
      | Papp (li, labels, args) when are_all_here labels ->
        Options.feedback ~dkey ~level:3
          "inlining Here labels for predicate: @[%a@]"
          Printer.pp_predicate p;
        let li = specialize li in
        (* The Cil visitor does not descend into [logic_info] definitions. *)
        let li = Visitor.visitFramacLogicInfo self li in
        let p = {p with pred_content = Papp(li, [], args)} in
        ChangeDoChildrenPost (p, fun x -> x)
      | _ -> DoChildren

    method !vterm t =
      match t.term_node with
      | Tapp(li, labels, args) when are_all_here labels ->
        Options.feedback ~dkey ~level:3
          "inlining Here labels for term: %a"
          Printer.pp_term t;
        let li = specialize li in
        (* The Cil visitor does not descend into [logic_info] definitions. *)
        let li = Visitor.visitFramacLogicInfo self li in
        let t = {t with term_node = Tapp(li, [], args)} in
        ChangeDoChildrenPost (t, fun x -> x)
      | _ -> DoChildren
  end

  let preprocess_pred p =
    match p.pred_content with
    | Papp(_li, labels, _args) when are_all_here labels ->
      Some (Visitor.visitFramacPredicate inliner p)
    | _ -> None

  let preprocess_term t =
    match t.term_node with
    | Tapp(_li, labels, _args) when are_all_here labels ->
      Some (Visitor.visitFramacTerm inliner t)
    | _ -> None

  (* apply to the result of a first preprocessor a second one *)
  let bind f orig = function
    | None -> f orig (* first preprocessor yields nothing, use original value *)
    | Some p -> match f p with
      | None -> Some p (* second preprocessor yields nothing *)
      | Some p -> Some p
end

let preprocess_pred ~loc p =
  Here_inliner.(bind preprocess_pred) p @@
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
        (* need to store a copy, to avoid p to appear in its own preprocessed
           form (otherwise it loops) *)
        let p_copy =
          match p.pred_content with
          | Pvalid_read _ -> Logic_const.pvalid_read ~loc (llabel, t)
          | Pvalid _ -> Logic_const.pvalid ~loc (llabel, t)
          | _ -> assert false
        in
        Some (Logic_const.pand ~loc (init, p_copy))
      | _ -> None
    end
  | _ -> None

let preprocess_term ~loc t =
  Here_inliner.(bind preprocess_term) t @@
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
  inherit E_acsl_visitor.visitor dkey

  method !vannotation annot =
    match annot with
    | Dfun_or_pred _ -> Cil.DoChildren
    | _ -> Cil.SkipChildren

  method !vpredicate  p =
    let loc = p.pred_loc in
    ignore @@ Predicates.memoize (preprocess_pred ~loc) p;
    Cil.DoChildren

  method !vterm t =
    let loc = t.term_loc in
    ignore @@ Terms.memoize (preprocess_term ~loc) t;
    Cil.DoChildren
end

let preprocess ast =
  preprocessor#visit_file ast

let preprocess_annot annot =
  ignore @@ preprocessor#visit_code_annot annot

let preprocess_predicate p =
  ignore @@ preprocessor#visit_predicate p

let get_pred = Predicates.normalized
let get_orig_pred = Predicates.original
let get_term = Terms.normalized
let get_orig_term = Terms.original

let clear () =
  Terms.clear ();
  Predicates.clear ();
  Here_specialized.clear ()
