(******************************************************************************)
(*                                                                            *)
(*  SPDX-License-Identifier LGPL-2.1                                          *)
(*  Copyright (C)                                                             *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)      *)
(*                                                                            *)
(******************************************************************************)

open Cil_types

exception Non_Transposable

let rec replace_formal_by_concrete vinfo = function
  | [] -> raise Non_Transposable
  | (x, t) :: tl ->
    if vinfo.vid = x.vid
    then t
    else replace_formal_by_concrete vinfo tl

(* Visitor to replace formal parameters by concrete arguments, given by the
   association list [arguments]. Also replaces logic label Pre by Here (valid at
   the call site).
   Raises Non_Transposable if the address of a formal is used, or if a formal is
   used under a label different from Pre and Here (the formal would be out of
   scope, but possibly not the concrete argument). *)
let replacement_visitor ~arguments = object (self)
  inherit Visitor.frama_c_copy (Project.current ())

  val mutable under_label = false

  method private is_under_label = function
    | BuiltinLabel (Pre | Here) -> false
    | _ -> true

  method private replace_tlval tlval =
    let t_lhost, t_offset = tlval in
    match t_lhost with
    | TMem _ ->
      let normalise_lval = function
        | TLval ((TMem {term_node=TAddrOf lv}), ofs) ->
          TLval (Logic_const.addTermOffsetLval ofs lv)
        | TLval ((TMem {term_node=TStartOf lv}), ofs) ->
          TLval (Logic_const.addTermOffsetLval (TIndex (Cil.lzero (), ofs)) lv)
        | x -> x
      in
      Cil.DoChildrenPost normalise_lval
    | TVar { lv_origin = Some vinfo } when vinfo.vformal ->
      if under_label then raise Non_Transposable;
      begin
        let post_replace _ =
          let new_term = replace_formal_by_concrete vinfo arguments in
          let add_offset lv =
            TLval (Logic_const.addTermOffsetLval t_offset lv)
          in
          match new_term.term_node with
          | TLval lv -> add_offset lv
          | node ->
            if t_offset = TNoOffset then node
            else
              let ltyp = new_term.term_type in
              let tmp_lvar = Cil.make_temp_logic_var ltyp in
              let tmp_linfo =
                { l_var_info = tmp_lvar; l_body = LBterm new_term;
                  l_type = None; l_tparams = []; l_labels = [];
                  l_profile = []; }
              in
              let lval_node = TLval (TVar tmp_lvar, t_offset) in
              Tlet (tmp_linfo, Logic_const.term lval_node ltyp)
        in
        Cil.DoChildrenPost post_replace
      end
    | _ -> Cil.DoChildren

  method! vterm_node = function
    | TConst _ | TSizeOf _
    | TAlignOf _ | Tnull | Ttype _ | Tempty_set -> Cil.SkipChildren
    | TLval tlval -> self#replace_tlval tlval
    | TAddrOf tlval ->
      begin
        match fst tlval with
        | TVar { lv_origin = Some vinfo } when vinfo.vformal ->
          raise Non_Transposable
        | _ -> Cil.DoChildren
      end
    | Tat (_, label) ->
      let previous_label = under_label in
      under_label <- self#is_under_label label;
      Cil.DoChildrenPost (fun t -> under_label <- previous_label; t)
    | _ -> Cil.DoChildren

  method! vlogic_label = function
    | BuiltinLabel Pre -> Cil.DoChildrenPost (fun _ -> Logic_const.here_label)
    | _ -> Cil.DoChildren
end

(* Associates each formal to a term corresponding to the concrete argument. *)
let rec associate acc xs es =
  match xs, es with
  | [], _ -> acc
  | _, [] -> raise Non_Transposable
  | x :: xs, e :: es ->
    let t = Logic_utils.expr_to_term e in
    associate ((x, t) :: acc) xs es

let term xs es term =
  try
    let arguments = associate [] xs es in
    let visitor :> Cil.cilVisitor = replacement_visitor ~arguments in
    Some (Cil.visitCilTerm visitor term)
  with Non_Transposable -> None

let pred xs es pred =
  try
    let arguments = associate [] xs es in
    let visitor :> Cil.cilVisitor = replacement_visitor ~arguments in
    Some (Cil.visitCilPredicate visitor pred)
  with Non_Transposable -> None

let ipred xs es id_pred =
  let pred = Logic_const.pred_of_id_pred id_pred in
  try
    let arguments = associate [] xs es in
    let visitor :> Cil.cilVisitor = replacement_visitor ~arguments in
    let new_pred = Cil.visitCilPredicateNode visitor pred.pred_content in
    let p_named =
      Logic_const.pred ~loc:pred.pred_loc ~names:pred.pred_name new_pred
    in
    let kind = id_pred.ip_content.tp_kind in
    Some (Logic_const.new_predicate ~kind p_named)
  with Non_Transposable -> None
