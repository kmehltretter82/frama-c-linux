(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

open Cil
open Cil_types
open Logic_const

let from_prototype kf =
  let vi = Kernel_function.get_vi kf in
  let formals =
    try
      let formals = getFormalsDecl vi in
      (* Do ignore anonymous names *)
      List.filter (fun vi -> vi.vname <> "") formals
    with Not_found -> []
    (* this may happen for function pointer used as formal parameters.*)
  in
  let rtyp, _, _, _ = splitFunctionTypeVI vi in
  let pointer_args,basic_args =
    List.partition (fun vi -> isPointerType vi.vtype) formals in
  (* Remove args of type pointer to pointer *)
  let pointer_args =
    List.filter
      (fun vi -> not (isPointerType (typeOf_pointed vi.vtype))) pointer_args
  in
  (* Convert void* pointers to char* *)
  let pointer_args =
    List.map
      (fun vi ->
         let loc = vi.vdecl in
         let t = tvar (cvar_to_lvar vi) in
         let typ = vi.vtype in
         if Cil.isVoidPtrType typ then
           let const = typeHasAttribute "const" (Cil.typeOf_pointed typ) in
           let typ' = if const then Cil.charConstPtrType else Cil.charPtrType in
           (vi.vghost, Logic_utils.mk_cast ~loc typ' t, typ')
         else (vi.vghost, t, typ)
      ) pointer_args
  in
  (* Generate the term [*(t+(0..))] with the appropriate array bounds (if
     they are known), and possibly add some [[..]] if v has points to one or
     more arrays *)
  let mk_star (g, t, typ) =
    let loc = t.term_loc in
    let zero = Logic_const.tinteger ~loc 0 in
    (* Range [0..length-1], or [0..] if length is not known *)
    let make_range length = match length with
      | None -> Logic_const.trange ~loc (Some zero, None)
      | Some length ->
        let high = Logic_const.tint ~loc (Integer.pred length) in
        Logic_const.trange ~loc (Some zero, Some high)
    in
    (* Generate the required numbers of [[..]] until with find a non-array
       type *)
    let rec mk_offset set typ =
      match Cil.unrollType typ with
      | TArray (typ_elem, size, _) ->
        let range = match size with
          | None -> make_range None
          | Some size ->
            make_range (Cil.constFoldToInt size)
        in
        let offs, typ = mk_offset true typ_elem in
        TIndex (range, offs), typ
      | _ ->
        TNoOffset,
        (if set then make_set_type (Ctype typ) else (Ctype typ))
    in
    (* make_set_type (Ctype typ_pointed) *)

    let typ_pointed = Cil.typeOf_pointed typ in
    (* Generate the initial term: [*(t+(0..))] for array types or char*
       pointers, *t for other pointer types. It would have been better to
       recognize formals with type [typ[]] instead of [typ *], but this
       information is lost during normalization *)
    let t_range_node, set =
      match findAttribute "arraylen" (typeAttr typ) with
      | [AInt length] -> TBinOp (PlusPI, t, make_range (Some length)), true
      | _ ->
        if Cil.isAnyCharPtrType typ
        then TBinOp (PlusPI, t, make_range None), true
        else t.term_node, false
    in
    let offset_arrays, typ_with_offset = mk_offset true typ_pointed in
    let t_range =
      Logic_const.term ~loc t_range_node (if set then make_set_type (Ctype typ) else Ctype typ)
    in
    let t = Logic_const.new_identified_term
        (term ~loc (TLval (TMem t_range, offset_arrays)) typ_with_offset)
    in
    (g, t)
  in
  let to_assign =
    List.map
      mk_star
      (List.filter
         (fun (_g, _t, typ) ->
            let pointed_type = typeOf_pointed typ in
            not (typeHasAttribute "const" pointed_type)
         )
         pointer_args)
  in
  let pointer_args_content =
    List.map mk_star pointer_args
  in
  let inputs =
    (pointer_args_content)
    @(List.map
        (fun v ->
           v.vghost,
           (Logic_const.new_identified_term
              { term_node = TLval (TVar (cvar_to_lvar v),TNoOffset);
                term_type = Ctype v.vtype;
                term_name = [];
                term_loc = v.vdecl })
        ) basic_args)
  in
  let inputs_no_ghost = List.fold_right
      (fun (g, t) acc -> if g then acc else t :: acc) inputs []
  in
  let inputs = List.map (fun (_g, t) -> t) inputs in
  let inputs g = if g then inputs else inputs_no_ghost in
  let arguments =
    List.map
      (fun (g, content) -> content, From (inputs g))
      to_assign
  in
  match rtyp with
  | TVoid _ ->
    (* assigns all pointer args from basic args and content of pointer args *)
    arguments
  | _ ->
    (* assigns result from basic args and content of pointer args *)
    let loc = vi.vdecl in
    let result = Logic_const.(new_identified_term (tresult ~loc rtyp)) in
    (result, From (inputs vi.vghost)):: arguments

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
