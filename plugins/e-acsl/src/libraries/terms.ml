(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

module Id = struct
  include Datatype.Make_with_hashtbl
      (struct
        include Cil_datatype.Term
        let name = "E_ACSL.Terms.Id"
        let compare = Datatype.undefined
        let equal (t1:term) t2 = t1 == t2
        let structural_descr = Structural_descr.t_abstract
        let rehash = Datatype.identity
        let mem_project = Datatype.never_any_project
      end)

  let term_copier = object
    inherit Visitor.frama_c_inplace
    method! vterm _ = Cil.DoChildrenPost (fun t -> {t with term_loc = t.term_loc})
    method! vlogic_type _ =
      (* optimisation: we copy terms and logic types do not contain terms *)
      Cil.SkipChildren
  end

  let deep_copy t = Visitor.visitFramacTerm term_copier t
  let deep_copy_predicate p = Visitor.visitFramacPredicate term_copier p
end

exception Range_found_exception
exception Lv_from_vi_found

let strip_shallow_cast t =
  match t.term_node with
  | TCast (_,_,t) -> t
  | _ -> t

let extract_integer t =
  match (strip_shallow_cast t).term_node with
  | TConst (Integer (z, _)) -> Some z
  | _ -> None

let of_li li =  match li.l_body with
  | LBterm t -> t
  | LBnone | LBreads _ | LBpred _ | LBinductive _ ->
    Options.fatal "li.l_body does not match LBterm(t) in Misc.term_of_li"

let is_range_free t =
  try
    let has_range_visitor = object inherit Visitor.frama_c_inplace
      method !vterm t = match t.term_node with
        | Trange _ -> raise Range_found_exception
        | _ -> Cil.DoChildren
    end
    in
    ignore (Visitor.visitFramacTerm has_range_visitor t);
    true
  with Range_found_exception ->
    false

let has_lv_from_vi t =
  try
    let o = object inherit Visitor.frama_c_inplace
      method !vlogic_var_use lv = match lv.lv_origin with
        | None -> Cil.DoChildren
        | Some _ -> raise Lv_from_vi_found
    end
    in
    ignore (Visitor.visitFramacTerm o t);
    false
  with Lv_from_vi_found ->
    true

let mk_TAddrOrTStartOf ~loc lval =
  let ltyp = Cil.typeOfTermLval lval in
  Id.deep_copy @@
  if Ast_types.Acsl.is_array ltyp
  then Logic_utils.mk_logic_StartOf @@ Logic_const.term (TLval lval) ltyp
  else Logic_utils.mk_logic_AddrOf ~loc lval ltyp
