(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(** This file contains types related types/functions/values. *)

open Cil_types

(* ********** *)
(* Attributes *)
(* ********** *)

let rec type_attrs { tnode; tattr } =
  match tnode with
  | TVoid    -> tattr
  | TInt _   -> tattr
  | TFloat _ -> tattr
  | TNamed t -> Ast_attributes.add_list tattr (type_attrs t.ttype)
  | TPtr _   -> tattr
  | TArray _ -> tattr
  | TComp comp -> Ast_attributes.add_list comp.cattr tattr
  | TEnum enum -> Ast_attributes.add_list enum.eattr tattr
  | TFun _   -> tattr
  | TBuiltin_va_list -> tattr

let rec type_add_attributes ?(combine=Ast_attributes.add_list) a0 t =
  begin
    match a0 with
    | [] ->
      (* no attributes, keep same type *)
      t
    | _ ->
      (* anything else: add a0 to existing attributes *)
      let add (a: attributes) = combine a0 a in
      match t.tnode with
      | TVoid
      | TInt   _
      | TFloat _
      | TEnum  _
      | TPtr   _
      | TFun   _
      | TComp  _
      | TNamed _
      | TBuiltin_va_list -> {t with tattr = add t.tattr}
      | TArray (bt, l) ->
        let att_elt, att_typ = Ast_attributes.split_array_attributes a0 in
        let bt' = array_push_attributes att_elt bt in
        let tattr = Ast_attributes.add_list att_typ t.tattr in
        Cil_const.mk_tarray ~tattr bt' l
  end
(* Push attributes that belong to the type of the elements of the array as
   far as possible *)
and array_push_attributes al t =
  match t.tnode with
  | TArray (bt, l) ->
    let bt' = array_push_attributes al bt in
    Cil_const.mk_tarray ~tattr:t.tattr bt' l
  | _ -> type_add_attributes al t

(**** Look for the presence of an attribute in a type ****)

let type_has_attribute attr typ = Ast_attributes.contains attr (type_attrs typ)

let rec type_has_qualifier attr t =
  match t.tnode with
  | TNamed ti ->
    Ast_attributes.contains attr t.tattr || type_has_qualifier attr ti.ttype
  | TArray (bt, _) ->
    type_has_qualifier attr bt
    || (* ill-formed type *) Ast_attributes.contains attr t.tattr
  | _ -> Ast_attributes.contains attr (type_attrs t)

let type_has_attribute_memory_block a (ty:typ): bool =
  let f attrs = if Ast_attributes.contains a attrs then raise Exit in
  let rec visit (t: typ) : unit =
    f t.tattr;
    match t.tnode with
    | TNamed r -> visit r.ttype
    | TArray (bt, _) -> visit bt
    | TComp comp ->
      List.iter
        (fun fi -> f fi.fattr; visit fi.ftype)
        (Option.value ~default:[] comp.cfields)
    | TVoid
    | TInt _
    | TFloat _
    | TEnum _
    | TFun _
    | TBuiltin_va_list
    | TPtr _ -> ()
  in
  try visit ty; false
  with Exit -> true

let rec type_remove_aux ?anl t =
  (* Try to preserve sharing. We use sharing to be more efficient, but also
     to detect that we have removed an attribute under typedefs *)
  let tattr =
    match anl with
    | None     -> []
    | Some anl -> Ast_attributes.drop_list anl t.tattr
  in
  let reshare () =
    if tattr == t.tattr
    then t
    else Cil_const.mk_typ ~tattr t.tnode
  in
  match t.tnode with
  | TVoid
  | TInt   _
  | TFloat _
  | TEnum  _
  | TPtr   _
  | TArray _
  | TFun   _
  | TComp  _
  | TBuiltin_va_list -> reshare ()
  | TNamed ti ->
    let tt = type_remove_aux ?anl ti.ttype in
    if tt == ti.ttype
    then reshare ()
    else type_add_attributes tattr tt

let type_remove_attributes anl t = type_remove_aux ~anl t

let type_remove_all_attributes t = type_remove_aux t

let rec type_remove_attributes_deep (anl: string list) t =
  (* Try to preserve sharing. We use sharing to be more efficient, but also
     to detect that we have removed an attribute under typedefs *)
  let reshare () =
    let tattr = Ast_attributes.drop_list anl t.tattr in
    if tattr == t.tattr
    then t
    else Cil_const.mk_typ ~tattr t.tnode
  in
  match t.tnode with
  | TVoid    -> reshare ()
  | TInt   _ -> reshare ()
  | TFloat _ -> reshare ()
  | TEnum  _ -> reshare ()
  | TPtr   t ->
    let t' = type_remove_attributes_deep anl t in
    if t != t'
    then Cil_const.mk_tptr ~tattr:(Ast_attributes.drop_list anl t.tattr) t'
    else reshare ()
  | TArray (t, l) ->
    let t' = type_remove_attributes_deep anl t in
    if t != t'
    then Cil_const.mk_tarray ~tattr:(Ast_attributes.drop_list anl t.tattr) t' l
    else reshare ()
  | TFun  _ -> reshare ()
  | TComp _ -> reshare ()
  | TBuiltin_va_list -> reshare ()
  | TNamed ti ->
    let tt = type_remove_attributes_deep anl ti.ttype in
    if tt == ti.ttype
    then reshare ()
    else type_add_attributes (Ast_attributes.drop_list anl t.tattr) tt

let type_remove_qualifier_attributes =
  type_remove_attributes Ast_attributes.qualifier_attributes

let type_remove_qualifier_attributes_deep =
  type_remove_attributes_deep Ast_attributes.qualifier_attributes

let type_remove_attributes_for_c_cast t =
  let attributes_to_remove =
    Ast_attributes.(fc_internal_attributes @ cast_irrelevant_attributes)
  in
  let t = type_remove_attributes_deep attributes_to_remove t in
  type_remove_attributes Ast_attributes.spare_attributes_for_c_cast t

let type_remove_attributes_for_logic_type t =
  let attributes_to_remove =
    Ast_attributes.(fc_internal_attributes @ cast_irrelevant_attributes)
  in
  let t = type_remove_attributes_deep attributes_to_remove t in
  type_remove_attributes Ast_attributes.spare_attributes_for_logic_cast t

(* ********** *)
(* Utils      *)
(* ********** *)

let unroll_type (t: typ) : typ =
  let rec with_attrs (al: attributes) (t: typ) : typ =
    match t.tnode with
    | TNamed ti -> with_attrs (Ast_attributes.add_list al t.tattr) ti.ttype
    | _ -> type_add_attributes al t
  in
  with_attrs [] t

let () = Cil_datatype.punrollType := unroll_type

let unroll_type_node (t: typ) : typ_node =
  (unroll_type t).tnode

let rec unroll_type_skel (t : typ) : typ_node =
  match t.tnode with
  | TNamed ti -> unroll_type_skel ti.ttype
  | _ -> t.tnode

let rec unroll_type_deep (t: typ) : typ =
  let rec with_attrs (al: attributes) (t: typ) : typ =
    match t.tnode with
    | TNamed r -> with_attrs (Ast_attributes.add_list al t.tattr) r.ttype
    | TPtr bt ->
      let bt' = unroll_type_deep bt in
      let tattr = Ast_attributes.add_list al t.tattr in
      Cil_const.mk_tptr ~tattr bt'
    | TArray (bt, l) ->
      let att_elt, att_typ = Ast_attributes.split_array_attributes al in
      let bt' = array_push_attributes att_elt (unroll_type_deep bt) in
      let tattr = Ast_attributes.add_list att_typ t.tattr in
      Cil_const.mk_tarray ~tattr bt' l
    | TFun (rt, args, isva) ->
      let rt' = unroll_type_deep rt in
      let args' =
        match args with
        | None -> None
        | Some argl ->
          Some (List.map (fun (an, at, aa) -> (an, unroll_type_deep at, aa)) argl)
      in
      let tattr = Ast_attributes.add_list al t.tattr in
      Cil_const.mk_tfun ~tattr rt' args' isva
    | _ -> type_add_attributes al t
  in
  with_attrs [] t

(* ************************* *)
(* Handling ghost attribute. *)
(* ************************* *)

let type_add_ghost typ =
  if not (type_has_attribute "ghost" typ) then
    type_add_attributes [("ghost", [])] typ
  else
    typ

let is_ghost_type typ_lval =
  type_has_attribute_memory_block "ghost" typ_lval

let rec is_wellformed_ghost_type t =
  is_wellformed_ghost_type' (unroll_type_deep t)
and is_wellformed_ghost_type' t =
  if not (is_ghost_type t) then is_wellformed_non_ghost_type t
  else match t.tnode with
    | TPtr t | TArray (t, _) -> is_wellformed_ghost_type' t
    | _ -> true
and is_wellformed_non_ghost_type t =
  if is_ghost_type t then false
  else match t.tnode with
    | TPtr t | TArray (t, _) -> is_wellformed_non_ghost_type t
    | _ -> true
