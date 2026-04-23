(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* This module contains types related types/functions/values in the module C
   and logic_type related functions in the module Acsl. *)

open Cil_types

(* Contains all functions related to C types. *)
module C = struct

  (* ********** *)
  (* Attributes *)
  (* ********** *)

  let rec get_attributes { tnode; tattr } =
    match tnode with
    | TVoid    -> tattr
    | TInt _   -> tattr
    | TFloat _ -> tattr
    | TNamed t -> Ast_attributes.add_list tattr (get_attributes t.ttype)
    | TPtr _   -> tattr
    | TArray _ -> tattr
    | TComp comp -> Ast_attributes.add_list comp.cattr tattr
    | TEnum enum -> Ast_attributes.add_list enum.eattr tattr
    | TFun _   -> tattr
    | TBuiltin_va_list -> tattr

  let rec add_attributes ?(push_qualifiers=true) a0 t =
    if a0 = [] then t
    else
      let add = Ast_attributes.add_list a0 in
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
        if not push_qualifiers then {t with tattr = add t.tattr}
        else
          let att_elt, att_typ = Ast_attributes.split_array_attributes a0 in
          let bt' = array_push_attributes att_elt bt in
          let tattr = Ast_attributes.add_list att_typ t.tattr in
          (* Push already done here, avoids infinite recursion. *)
          Cil_const.mk_tarray ~push_qualifiers:false ~tattr bt' l

  (* Push attributes that belong to the type of the elements of the array as
     far as possible. *)
  and array_push_attributes al t =
    match t.tnode with
    | TArray (bt, l) ->
      let bt' = array_push_attributes al bt in
      (* Push already done here, avoids infinite recursion. *)
      Cil_const.mk_tarray ~push_qualifiers:false ~tattr:t.tattr bt' l
    | _ -> add_attributes al t

  let () =
    Cil_const.add_attributes_ref := add_attributes
  [@@alert "-add_attributes_ref"]

  (* *** Look for the presence of an attribute in a type *** *)

  let has_attribute attr typ =
    Ast_attributes.contains attr (get_attributes typ)

  let rec has_qualifier attr t =
    match t.tnode with
    | TNamed ti ->
      Ast_attributes.contains attr t.tattr || has_qualifier attr ti.ttype
    | TArray (bt, _) ->
      has_qualifier attr bt
      || (* ill-formed type *) Ast_attributes.contains attr t.tattr
    | _ -> Ast_attributes.contains attr (get_attributes t)

  let has_attribute_memory_block a (ty:typ): bool =
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

  let rec remove_aux ?anl t =
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
      let tt = remove_aux ?anl ti.ttype in
      if tt == ti.ttype
      then reshare ()
      else add_attributes tattr tt

  let remove_attributes anl t = remove_aux ~anl t

  let remove_all_attributes t = remove_aux t

  let rec remove_attributes_deep (anl: string list) t =
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
      let t' = remove_attributes_deep anl t in
      if t != t'
      then Cil_const.mk_tptr ~tattr:(Ast_attributes.drop_list anl t.tattr) t'
      else reshare ()
    | TArray (t, l) ->
      let t' = remove_attributes_deep anl t in
      if t != t'
      then Cil_const.mk_tarray ~tattr:(Ast_attributes.drop_list anl t.tattr) t' l
      else reshare ()
    | TFun(rt,args,va) ->
      let rt' = remove_attributes_deep anl rt in
      let args' =
        Option.map_no_copy
          (List.map_no_copy
             (fun (x,t,a as orig) ->
                let t' = remove_attributes_deep anl t in
                if t == t' then orig else (x,t',a)))
          args
      in
      if rt' != rt || args' != args then
        Cil_const.mk_tfun ~tattr:(Ast_attributes.drop_list anl t.tattr) rt' args' va
      else
        reshare ()
    | TComp _ -> reshare ()
    | TBuiltin_va_list -> reshare ()
    | TNamed ti ->
      let tt = remove_attributes_deep anl ti.ttype in
      if tt == ti.ttype
      then reshare ()
      else add_attributes (Ast_attributes.drop_list anl t.tattr) tt

  let remove_qualifiers =
    remove_attributes Ast_attributes.qualifier_attributes

  let remove_qualifiers_deep =
    remove_attributes_deep Ast_attributes.qualifier_attributes

  let remove_attributes_for_c_cast t =
    let attributes_to_remove =
      Ast_attributes.(fc_internal_attributes @ cast_irrelevant_attributes)
    in
    let t = remove_attributes_deep attributes_to_remove t in
    remove_attributes Ast_attributes.spare_attributes_for_c_cast t

  let remove_attributes_for_logic_type t =
    let attributes_to_remove =
      Ast_attributes.(fc_internal_attributes @ cast_irrelevant_attributes)
    in
    let t = remove_attributes attributes_to_remove t in
    remove_attributes Ast_attributes.spare_attributes_for_logic_cast t

  (* ********** *)
  (* Utils      *)
  (* ********** *)

  (* Unrolling *)

  let unroll (t: typ) : typ =
    let rec with_attrs (al: attributes) (t: typ) : typ =
      match t.tnode with
      | TNamed ti -> with_attrs (Ast_attributes.add_list al t.tattr) ti.ttype
      | _ -> add_attributes al t
    in
    with_attrs [] t

  let () = Cil_datatype.punrollType := unroll

  let unroll_node (t: typ) : typ_node =
    (unroll t).tnode

  let rec unroll_skel (t : typ) : typ_node =
    match t.tnode with
    | TNamed ti -> unroll_skel ti.ttype
    | _ -> t.tnode

  let rec unroll_deep (t: typ) : typ =
    let rec with_attrs (al: attributes) (t: typ) : typ =
      match t.tnode with
      | TNamed r -> with_attrs (Ast_attributes.add_list al t.tattr) r.ttype
      | TPtr bt ->
        let bt' = unroll_deep bt in
        let tattr = Ast_attributes.add_list al t.tattr in
        Cil_const.mk_tptr ~tattr bt'
      | TArray (bt, l) ->
        let att_elt, att_typ = Ast_attributes.split_array_attributes al in
        let bt' = array_push_attributes att_elt (unroll_deep bt) in
        let tattr = Ast_attributes.add_list att_typ t.tattr in
        Cil_const.mk_tarray ~tattr bt' l
      | TFun (rt, args, isva) ->
        let rt' = unroll_deep rt in
        let args' =
          match args with
          | None -> None
          | Some argl ->
            Some (List.map (fun (an, at, aa) -> (an, unroll_deep at, aa)) argl)
        in
        let tattr = Ast_attributes.add_list al t.tattr in
        Cil_const.mk_tfun ~tattr rt' args' isva
      | _ -> add_attributes al t
    in
    with_attrs [] t

  let unroll_deep_node (t: typ) : typ_node =
    (unroll_deep t).tnode

  (* ************************* *)
  (* Handling const attribute. *)
  (* ************************* *)

  let is_const typ_lval = has_attribute_memory_block "const" typ_lval

  (* **************************** *)
  (* Handling volatile attribute. *)
  (* **************************** *)

  let is_volatile typ_lval = has_attribute_memory_block "volatile" typ_lval

  (* ************************* *)
  (* Handling ghost attribute. *)
  (* ************************* *)

  let add_ghost typ =
    if not (has_attribute "ghost" typ) then
      add_attributes [("ghost", [])] typ
    else
      typ

  let is_ghost typ_lval =
    has_attribute_memory_block "ghost" typ_lval

  let rec is_wellformed_ghost t =
    is_wellformed_ghost' (unroll_deep t)
  and is_wellformed_ghost' t =
    if not (is_ghost t) then is_wellformed_non_ghost t
    else match t.tnode with
      | TPtr t | TArray (t, _) -> is_wellformed_ghost' t
      | _ -> true
  and is_wellformed_non_ghost t =
    if is_ghost t then false
    else match t.tnode with
      | TPtr t | TArray (t, _) -> is_wellformed_non_ghost t
      | _ -> true

  (* ************** *)
  (* Type checkers. *)
  (* ************** *)

  let is_void t =
    match unroll_skel t with
    | TVoid -> true
    | _ -> false

  let is_void_ptr t =
    match unroll_skel t with
    | TPtr t when is_void t -> true
    | _ -> false

  let is_bool t =
    match unroll_skel t with
    | TInt IBool -> true
    | _ -> false

  let is_char t =
    match unroll_skel t with
    | TInt IChar -> true
    | _ -> false

  let is_any_char t =
    match unroll_skel t with
    | TInt (IChar | ISChar | IUChar) -> true
    | _ -> false

  let is_char_ptr t =
    match unroll_skel t with
    | TPtr t when is_char t -> true
    | _ -> false

  let is_any_char_ptr t =
    match unroll_skel t with
    | TPtr t when is_any_char t -> true
    | _ -> false

  let is_char_const_ptr t =
    match unroll t with
    | { tnode = TPtr t; tattr } when is_char t ->
      Ast_attributes.contains "const" tattr
    | _ -> false

  let is_short t =
    match unroll_skel t with
    | TInt (IUShort | IShort) -> true
    | _ -> false

  let is_integral t =
    match unroll_skel t with
    | (TInt _ | TEnum _) -> true
    | _ -> false

  (* Don't completely unroll here, as we do not want to identify
     intptr_t with its supporting integer type. *)
  let rec is_intptr_t t =
    match t.tnode with
    | TNamed ti -> ti.tname = "intptr_t" || is_intptr_t ti.ttype
    | _ -> false

  let rec is_uintptr_t  t =
    match t.tnode with
    | TNamed ti -> ti.tname = "uintptr_t" || is_uintptr_t ti.ttype
    | _ -> false

  let is_float t =
    match unroll_skel t with
    | TFloat _ -> true
    | _ -> false

  let is_long_double t =
    match unroll_skel t with
    | TFloat FLongDouble -> true
    | _ -> false

  (* ISO 6.2.5.18 *)
  let is_arithmetic t =
    match unroll_skel t with
    | (TInt _ | TEnum _ | TFloat _) -> true
    | _ -> false

  let is_ptr t =
    match unroll_skel t with
    | TPtr _ -> true
    | _ -> false

  let is_integral_or_pointer t =
    is_integral t || is_ptr t

  let is_array t =
    match unroll_skel t with
    | TArray _ -> true
    | _ -> false

  let is_unsized_array t =
    match unroll_skel t with
    | TArray (_, None) -> true
    | _ -> false

  let is_sized_array t =
    match unroll_skel t with
    | TArray (_, Some _) -> true
    | _ -> false

  let is_char_array t = match unroll_skel t with
    | TArray(tau, _) when is_char tau -> true
    | _ -> false

  let is_any_char_array t = match unroll_skel t with
    | TArray(tau, _) when is_any_char tau -> true
    | _ -> false

  let is_wchar_array t = match unroll_skel t with
    | TArray(tau, _) ->
      Cil_datatype.TypNoAttrs.equal tau (Machine.wchar_type ())
    | _ -> false

  let is_fun t =
    match unroll_skel t with
    | TFun _ -> true
    | _ -> false

  let is_variadic t =
    match unroll_skel t with
    | TFun (_, _, va) -> va
    | _ -> false

  let is_fun_ptr t =
    match unroll_skel t with
    | TPtr t -> is_fun t
    | _ -> false

  let is_fun_or_ptr t =
    match unroll_skel t with
    | TPtr _ | TFun _ -> true
    | _ -> false

  (* ISO 6.2.5.21 *)
  let is_scalar t =
    is_arithmetic t || is_ptr t

  (* ISO 6.2.5.1 *)
  let is_object t =
    not (is_fun t)

  let is_object_ptr t =
    match unroll_skel t with
    | TPtr t -> is_object t
    | _ -> false

  let is_struct t =
    match unroll_skel t with
    | TComp ci -> ci.cstruct
    | _ -> false

  let is_union t =
    match unroll_skel t with
    | TComp ci -> not ci.cstruct
    | _ -> false

  let has_bitfield t =
    match unroll_skel t with
    | TComp { cfields = Some l } ->
      List.exists (fun f -> Option.is_some f.fbitfield) l
    | _ -> false

  let is_struct_or_union t =
    match unroll_skel t with
    | TComp _ -> true
    | _ -> false

  (* Check if a type is a transparent union, and return the first field if it is. *)
  let is_transparent_union t =
    match unroll_skel t with
    | TComp ci when not ci.cstruct ->
      (* Turn transparent unions into the type of their first field. *)
      if has_attribute "transparent_union" t then begin
        match ci.cfields with
        | Some [] | None ->
          let name =
            (if ci.cstruct then "struct " else "union ") ^ ci.cname
          in
          Errorloc.abort_context "Empty transparent union: %s" name
        | Some (f :: _) -> Some f
      end else
        None
    | _ -> None

  let is_variadic_list t =
    match unroll_skel t with
    | TBuiltin_va_list -> true
    | _ -> false

  (* ************ *)
  (* Type access. *)
  (* ************ *)

  let direct_array_element t =
    match unroll_node t with
    | TArray (elem_t, _) -> elem_t
    | _ -> Kernel.fatal "Not an array type %a" Cil_datatype.Typ.pretty t

  let rec array_element t =
    let t' = direct_array_element t in
    match unroll_node t' with
    | TArray _ -> array_element t'
    | _ -> t'

  let array_elem_type_and_size t =
    match unroll_node t with
    | TArray (ty_elem, arr_size) -> ty_elem, arr_size
    | _ -> Kernel.fatal "Not an array type %a" Cil_datatype.Typ.pretty t

  let direct_pointed_type t =
    match unroll_skel t with
    | TPtr t -> t
    | _ -> Kernel.fatal "Not a pointer type %a" Cil_datatype.Typ.pretty t

  let pointed_type t =
    let t' = direct_pointed_type t in
    match unroll_node t' with
    | TArray _ -> array_element t'
    | _ -> t'

end

(* ********************* *)
(* Logic Type utilities. *)
(* ********************* *)

module Acsl = struct

  let rec instantiate subst = function
    | Ltype(ty,prms) -> Ltype(ty, List.map (instantiate subst) prms)
    | Larrow(args,rt) ->
      Larrow(List.map (instantiate subst) args, instantiate subst rt)
    | Lvar v as ty ->
      (* This is an application of type parameters:
         no need to recursively substitute in the resulting type. *)
      (try List.assoc v subst with Not_found -> ty)
    | Ctype _ | Linteger | Lreal | Lboolean as ty -> ty

  let is_unrollable_ltdef = function
    | {lt_def=Some (LTsyn _)} -> true
    | {lt_def=Some (LTsum _)} | {lt_def=None} -> false

  let rec unroll_ltdef = function
    | Ltype ({lt_def=Some (LTsyn ty);lt_params},prms) ->
      let subst =
        try
          List.combine lt_params prms
        with Invalid_argument _ ->
          Kernel.fatal "Logic type used with wrong number of parameters"
      in
      unroll_ltdef (instantiate subst ty)
    | Ltype ({lt_def= None},_)
    | Ltype ({lt_def= Some (LTsum _)},_)
    | Linteger | Lboolean | Lreal | Lvar _ | Larrow _ | Ctype _ as ty  -> ty

  let rec unroll ?(unroll_typedef=true) = function
    | Ltype (tdef,_) as ty when is_unrollable_ltdef tdef ->
      unroll ~unroll_typedef (unroll_ltdef ty)
    | Ctype ty when unroll_typedef -> Ctype (C.unroll ty)
    | Linteger | Lboolean | Lreal | Lvar _ | Larrow _ | Ctype _ | Ltype _ as ty ->
      ty

  let () = Cil_datatype.punrollLogicType := unroll

  (* Utils function for is_plain_* functions. *)
  let unroll_aux is_logic lti t =
    is_unrollable_ltdef lti && is_logic (unroll_ltdef t)

  let rec is_plain_volatile t =
    match t with
    | Ctype typ -> C.is_volatile typ
    | Lboolean | Linteger | Lreal | Lvar _ | Larrow _ -> false
    | Ltype (lti,_) -> unroll_aux is_plain_volatile lti t

  let rec is_plain_typetag t =
    match t with
    | Ltype ({lt_name = "typetag"}, []) -> true
    | Ltype (lti, _) -> unroll_aux is_plain_typetag lti t
    | _ -> false

  let rec is_plain_boolean t =
    match t with
    | Ctype t -> C.is_integral t
    | Lboolean | Linteger -> true
    | Ltype (lti, _) -> unroll_aux is_plain_boolean lti t
    | Lreal | Lvar _ | Larrow _ -> false

  let rec is_plain_pure_boolean t =
    match t with
    | Ctype t -> C.is_bool t
    | Lboolean -> true
    | Ltype (lti, _) -> unroll_aux is_plain_pure_boolean lti t
    | _ -> false

  let rec is_logic_boolean = function
    | Lboolean -> true
    | Ltype (tdef,_) as ty when is_unrollable_ltdef tdef ->
      is_logic_boolean (unroll_ltdef ty)
    | _ -> false

  let rec is_plain_integral t =
    match t with
    | Ctype t -> C.is_integral t
    | Lboolean -> false
    | Linteger -> true
    | Lreal -> false
    | Ltype (lti, _) -> unroll_aux is_plain_integral lti t
    | Lvar _ | Larrow _ -> false

  let rec is_plain_real t =
    match t with
    | Ctype _ -> false
    | Lboolean -> false
    | Linteger -> false
    | Lreal -> true
    | Ltype (lti, _) -> unroll_aux is_plain_real lti t
    | Lvar _ | Larrow _ -> false

  let rec is_plain_real_or_float t =
    match t with
    | Ctype t -> C.is_float t
    | Lboolean -> false
    | Linteger -> false
    | Lreal -> true
    | Ltype (lti, _) -> unroll_aux is_plain_real_or_float lti t
    | Lvar _ | Larrow _ -> false

  let rec is_plain_arithmetic t =
    match t with
    | Ctype t -> C.is_arithmetic t
    | Linteger | Lreal -> true
    | Ltype (lti, _) -> unroll_aux is_plain_arithmetic lti t
    | Lboolean | Lvar _ | Larrow _ -> false

  let rec fold_plain_ctype ~default f = function
    | Ltype (tdef,_) as ty when is_unrollable_ltdef tdef ->
      fold_plain_ctype ~default f (unroll_ltdef ty)
    | Ltype _ | Linteger | Lboolean | Lreal | Lvar _ | Larrow _ -> default
    | Ctype cty  -> f cty

  let is_plain_ctype = fold_plain_ctype ~default:false

  let is_plain_float = is_plain_ctype C.is_float

  let is_plain_ptr = is_plain_ctype C.is_ptr

  let is_plain_fun = is_plain_ctype C.is_fun

  let is_plain_fun_ptr = is_plain_ctype C.is_fun_ptr

  let is_plain_fun_or_ptr = is_plain_ctype C.is_fun_or_ptr

  let is_plain_array = is_plain_ctype C.is_array

  let rec is_plain_list = function
    | Ltype ({lt_name = "\\list"},[_]) -> true
    | Ltype (tdef,_) as ty when is_unrollable_ltdef tdef ->
      is_plain_list (unroll_ltdef ty)
    | _ -> false

  let make_list ty =
    Ltype(Logic_env.find_logic_type "\\list",[ty])

  let rec list_element ty = match ty with
    | Ltype ({lt_name = "\\list"},[t]) -> t
    | Ltype (tdef,_) as ty when is_unrollable_ltdef tdef ->
      list_element (unroll_ltdef ty)
    | _ -> failwith "not a list type"

  let rec is_plain_set = function
    | Ltype ({lt_name = "set"},[_]) -> true
    | Ltype (tdef,_) as ty when is_unrollable_ltdef tdef ->
      is_plain_set (unroll_ltdef ty)
    | _ -> false

  let make_set ty =
    if is_plain_set ty then ty
    else Ltype(Logic_env.find_logic_type "set",[ty])

  let set_conversion ty1 ty2 =
    if is_plain_set ty2 then make_set ty1 else ty1

  let rec set_element ty = match ty with
    | Ltype ({lt_name = "set"},[t]) -> t
    | Ltype (tdef,_) as ty when is_unrollable_ltdef tdef ->
      set_element (unroll_ltdef ty)
    | _ -> failwith "not a set type"

  let plain_or_set f = function
    | Ltype ({lt_name = "set"},[t]) -> f t
    | Ltype (tdef,_) as t when is_unrollable_ltdef tdef -> begin
        match unroll_ltdef t with
        | Ltype ({lt_name = "set"},[t]) -> f t
        | _ -> f t
      end
    | t -> f t

  let transform_element f t = set_conversion (plain_or_set f t) t

  let is_plain ty = not (is_plain_set ty)

  let make_arrow args rt =
    match args with
    | [] -> rt
    | _ -> Larrow(List.map (fun x -> x.lv_type) args, rt)

  let is_arithmetic = plain_or_set is_plain_arithmetic

  let is_integral = plain_or_set is_plain_integral

  let plain_or_set_ctype f =
    plain_or_set (fold_plain_ctype ~default:false f)

  let is_char = plain_or_set_ctype C.is_char

  let is_any_char = plain_or_set_ctype C.is_any_char

  let is_void = plain_or_set_ctype C.is_void

  let is_array = plain_or_set is_plain_array

  let is_ptr = plain_or_set is_plain_ptr

  let is_fun_ptr = plain_or_set is_plain_fun_ptr

  let is_void_ptr = plain_or_set_ctype C.is_void_ptr

  let pointed =
    transform_element
      (fun t ->
         match unroll t with
         | Ctype ty when C.is_ptr ty ->
           Ctype (C.direct_pointed_type ty)
         | _ ->
           Kernel.fatal ~current:true "type %a is not a pointer type"
             Cil_datatype.Logic_type.pretty t)

  let rec ctype_of_pointed t =
    match unroll t with
    | Ctype ty when C.is_ptr ty -> C.direct_pointed_type ty
    | Ltype ({lt_name = "set"},[t]) -> ctype_of_pointed t
    | _ ->
      Kernel.fatal ~current:true "type %a is not a pointer type"
        Cil_datatype.Logic_type.pretty t

  let array_element =
    transform_element
      (fun t ->
         match unroll t with
         | Ctype ty when C.is_array ty ->
           Ctype (C.direct_array_element ty)
         | _ ->
           Kernel.fatal ~current:true "type %a is not an array type"
             Cil_datatype.Logic_type.pretty t)

  let rec ctype_of_array_elem t =
    match unroll t with
    | Ctype ty when C.is_array ty -> C.direct_array_element ty
    | Ltype ({lt_name = "set"},[t]) -> ctype_of_array_elem t
    | _ ->
      Kernel.fatal ~current:true "type %a is not an array type"
        Cil_datatype.Logic_type.pretty t

  let get_ctype t =
    let rec get_aux = function
      | Ctype t -> t
      | Ltype (tdef,_) as ty when is_unrollable_ltdef tdef ->
        get_aux (unroll_ltdef ty)
      | Lvar _ -> Cil_const.intType
      | _ -> failwith "not a C type"
    in
    plain_or_set get_aux t

  let remove_qualifiers =
    let plain typ =
      match unroll typ with
      | Ctype t ->
        let t' = C.remove_qualifiers t in
        if Cil_datatype.Typ.equal t t' then typ else Ctype t'
      | _ -> typ
    in
    transform_element plain

  let rec arithmetic_conversion ty1 ty2 =
    match unroll ty1, unroll ty2 with
    | Ctype ty1, Ctype ty2 ->
      if C.is_integral ty1 && C.is_integral ty2
      then Linteger
      else Lreal
    | (Linteger, Ctype t | Ctype t, Linteger) when C.is_integral t ->
      Linteger
    | (Linteger, Ctype t | Ctype t , Linteger)
      when C.is_arithmetic t-> Lreal
    | (Lreal, Ctype ty | Ctype ty, Lreal)
      when C.is_arithmetic ty -> Lreal
    | Linteger, Linteger -> Linteger
    | (Lreal | Linteger) , (Lreal | Linteger) -> Lreal
    | Ltype ({lt_name="set"} as lt,[t1]),
      Ltype ({lt_name="set"},[t2]) ->
      Ltype(lt,[arithmetic_conversion t1 t2])
    | Ltype ({lt_name="set"} as lt,[t1]), t2 ->
      Ltype(lt, [arithmetic_conversion t1 t2])
    | t1, Ltype({lt_name = "set"} as lt, [t2]) ->
      Ltype(lt, [arithmetic_conversion t1 t2])
    | _ ->
      Kernel.fatal
        ~current:true
        "arithmetic conversion between non arithmetic types %a and %a"
        Cil_datatype.Logic_type.pretty ty1 Cil_datatype.Logic_type.pretty ty2
end

(* Deprecated logic functions *)

let unroll_logic = Acsl.unroll

let is_logic_volatile = Acsl.is_plain_volatile

let is_logic_typetag = Acsl.is_plain_typetag

let is_logic_boolean = Acsl.is_plain_boolean

let is_logic_pure_boolean = Acsl.is_plain_pure_boolean

let is_logic_integral = Acsl.is_plain_integral

let is_logic_float = Acsl.is_plain_float

let is_logic_real = Acsl.is_plain_real

let is_logic_real_or_float = Acsl.is_plain_real_or_float

let is_logic_arithmetic = Acsl.is_plain_arithmetic

let is_logic_ptr = Acsl.is_plain_ptr

let is_logic_fun = Acsl.is_plain_fun

let is_logic_fun_ptr = Acsl.is_plain_fun_ptr

let is_logic_fun_or_ptr = Acsl.is_plain_fun_or_ptr

(* Deprecated c functions *)

let get_attributes = C.get_attributes

let add_attributes = C.add_attributes

let has_attribute = C.has_attribute

let has_qualifier = C.has_qualifier

let has_attribute_memory_block = C.has_attribute_memory_block

let remove_attributes = C.remove_attributes

let remove_all_attributes = C.remove_all_attributes

let remove_attributes_deep = C.remove_attributes_deep

let remove_qualifiers = C.remove_qualifiers

let remove_qualifiers_deep = C.remove_qualifiers_deep

let remove_attributes_for_c_cast = C.remove_attributes_for_c_cast

let remove_attributes_for_logic_type = C.remove_attributes_for_logic_type

let unroll = C.unroll

let unroll_node = C.unroll_node

let unroll_skel = C.unroll_skel

let unroll_deep = C.unroll_deep

let unroll_deep_node = C.unroll_deep_node

let is_const = C.is_const

let is_volatile = C.is_volatile

let add_ghost = C.add_ghost

let is_ghost = C.is_ghost

let is_wellformed_ghost = C.is_wellformed_ghost

let is_void = C.is_void

let is_void_ptr = C.is_void_ptr

let is_bool = C.is_bool

let is_char = C.is_char

let is_any_char = C.is_any_char

let is_char_ptr = C.is_char_ptr

let is_any_char_ptr = C.is_any_char_ptr

let is_char_const_ptr = C.is_char_const_ptr

let is_short = C.is_short

let is_integral = C.is_integral

let is_intptr_t = C.is_intptr_t

let is_uintptr_t = C.is_uintptr_t

let is_float = C.is_float

let is_long_double = C.is_long_double

let is_arithmetic = C.is_arithmetic

let is_ptr = C.is_ptr

let is_integral_or_pointer = C.is_integral_or_pointer

let is_array = C.is_array

let is_unsized_array = C.is_unsized_array

let is_sized_array = C.is_sized_array

let is_char_array = C.is_char_array

let is_any_char_array = C.is_any_char_array

let is_wchar_array = C.is_wchar_array

let is_fun = C.is_fun

let is_variadic = C.is_variadic

let is_fun_ptr = C.is_fun_ptr

let is_fun_or_ptr = C.is_fun_or_ptr

let is_scalar = C.is_scalar

let is_object = C.is_object

let is_object_ptr = C.is_object_ptr

let is_struct = C.is_struct

let is_union = C.is_union

let has_bitfield = C.has_bitfield

let is_struct_or_union = C.is_struct_or_union

let is_transparent_union = C.is_transparent_union

let is_variadic_list = C.is_variadic_list

let direct_element_type = C.direct_array_element

let element_type = C.array_element

let array_elem_type_and_size = C.array_elem_type_and_size

let direct_pointed_type = C.direct_pointed_type

let pointed_type = C.pointed_type
