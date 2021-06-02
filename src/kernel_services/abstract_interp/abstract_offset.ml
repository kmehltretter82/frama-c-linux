(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(* Implementation from Bit_utils *)
let rec type_compatible t1 t2 =
  match Cil.unrollType t1, Cil.unrollType t2 with
  | TVoid _, TVoid _ -> true
  | TInt (i1, _), TInt (i2, _) -> i1 = i2
  | TFloat (f1, _), TFloat (f2, _) -> f1 = f2
  | TPtr (t1, _), TPtr (t2, _) -> type_compatible t1 t2
  | TArray (t1', s1, _, _), TArray (t2', s2, _, _) ->
    type_compatible t1' t2' &&
    (s1 == s2 || try Integer.equal (Cil.lenOfArray64 s1) (Cil.lenOfArray64 s2)
     with Cil.LenOfArray -> false)
  | TFun (r1, a1, v1, _), TFun (r2, a2, v2, _) ->
    v1 = v2 && type_compatible r1 r2 &&
    (match a1, a2 with
     | None, _ | _, None -> true
     | Some l1, Some l2 ->
       try
         List.for_all2
           (fun (_, t1, _) (_, t2, _) -> type_compatible t1 t2) l1 l2
       with Invalid_argument _ -> false)
  | TNamed _, TNamed _ -> assert false
  | TComp (c1, _, _), TComp (c2, _, _) -> c1.ckey = c2.ckey
  | TEnum (e1, _), TEnum (e2, _) -> e1.ename = e2.ename
  | TBuiltin_va_list _, TBuiltin_va_list _ -> true
  | (TVoid _ | TInt _ | TFloat _ | TPtr _ | TArray _ | TFun _ | TNamed _ |
     TComp _ | TEnum _ | TBuiltin_va_list _), _ ->
    false

module type T =
sig
  type t

  val pretty : Format.formatter -> t -> unit
  val append : t -> t -> t (* Does not check that the appened offset fits *)
  val join : t -> t -> t
  val of_cil_offset : (Cil_types.exp -> Ival.t) -> Cil_types.typ -> Cil_types.offset -> t
  val of_ival : base_typ:Cil_types.typ -> typ:Cil_types.typ -> Ival.t -> t
  val of_term_offset : Cil_types.typ -> Cil_types.term_offset -> t
  val is_singleton : t -> bool
end

type typed_offset =
  | NoOffset of Cil_types.typ
  | Index of Ival.t * Cil_types.typ * typed_offset
  | Field of Cil_types.fieldinfo * typed_offset


module TypedOffset =
struct
  type t = typed_offset

  let rec pretty fmt = function
    | NoOffset _t -> ()
    | Field (fi, s) -> Format.fprintf fmt ".%s%a" fi.fname pretty s
    | Index (i, _t, s) -> Format.fprintf fmt "[%a]%a" Ival.pretty i pretty s

  let rec append o1 o2 =
    match o1 with
    | NoOffset _t -> o2
    | Field (fi, s) -> Field (fi, append s o2)
    | Index (i, t, s) -> Index (i, t, append s o2)

  let rec join o1 o2 =
    match o1, o2 with
    | NoOffset t, NoOffset t' when type_compatible t t' ->
      NoOffset t
    | Field (fi, s1), Field (fi', s2) when Cil_datatype.Fieldinfo.equal fi fi' ->
      Field (fi, join s1 s2)
    | Index (i1, t, s1), Index (i2, t', s2) when type_compatible t t' ->
      Index (Ival.join i1 i2, t, join s1 s2)
    | _ -> raise Abstract_interp.Error_Top

  let array_bounds array_size =
    (* TODO: handle undefined sizes and not const foldable sizes *)
    match array_size with
    | None -> None, None
    | Some size_exp ->
      Some Integer.zero,
      Option.map Integer.pred (Cil.constFoldToInt size_exp)

  let array_range array_size =
    let l,u = array_bounds array_size in
    Ival.inject_range l u

  let assert_valid_index idx size =
    let range = array_range size in
    if not (Ival.is_included idx range) then
      raise Abstract_interp.Error_Top

  let rec of_cil_offset oracle base_typ = function
    | Cil_types.NoOffset -> NoOffset base_typ
    | Field (fi, sub) -> Field (fi, of_cil_offset oracle fi.ftype sub)
    | Index (exp, sub) ->
      match Cil.unrollType base_typ with
      | TArray (elem_typ, array_size, _, _) ->
        let idx = oracle exp in
        assert_valid_index idx array_size;
        Index (idx, elem_typ, of_cil_offset oracle elem_typ sub)
      | _ -> assert false

  let rec of_ival ~base_typ ~typ ival =
    if Ival.is_zero ival && type_compatible base_typ typ then
      NoOffset typ
    else
      match Cil.unrollType base_typ with
      | TArray (elem_typ, array_size, _, _) ->
        let range, rem =
          try
            let elem_size = Integer.of_int (Cil.bitsSizeOf elem_typ) in
            if Integer.is_zero elem_size then (* array of elements of size 0 *)
              if Ival.is_zero ival then (* the whole range is valid *)
                array_range array_size, ival
              else (* Non-zero offset cannot represent anything here *)
                raise Abstract_interp.Error_Top
            else
              Ival.scale_div ~pos:true elem_size ival,
              Ival.scale_rem ~pos:true elem_size ival
          with Cil.SizeOfError (_,_) ->
            (* Cil.bitsSizeOf can raise an exception when elements are
               themselves array of execution-time size *)
            if Ival.is_zero ival then
              ival, ival
            else
              raise Abstract_interp.Error_Top
        in
        assert_valid_index range array_size;
        let sub = of_ival ~base_typ:elem_typ ~typ rem in
        Index (range, elem_typ, sub)

      | TComp (ci, _, _) ->
        if not ci.cstruct then
          (* Ignore unions for now *)
          raise Abstract_interp.Error_Top
        else
          let rec find_field = function
            | [] -> raise Abstract_interp.Error_Top
            | fi :: q ->
              let offset, width = Cil.fieldBitsOffset fi in
              let l = Integer.(of_int offset) in
              let u = Integer.(pred (add l (of_int width))) in
              let range = Ival.inject_range (Some l) (Some u) in
              if Ival.is_included ival range then
                let sub_ival = Ival.add_singleton_int (Integer.neg l) ival in
                Field (fi, of_ival ~base_typ:fi.ftype ~typ sub_ival)
              else
                find_field q
          in
          find_field (Option.value ~default:[] ci.cfields)

      | _ -> raise Abstract_interp.Error_Top

  let index_of_term array_size t = (* Exact constant ranges *)
    match t.Cil_types.term_node with
    | Tempty_set -> Ival.bottom
    | TConst (Integer (v, _)) -> Ival.inject_singleton v
    | Trange (l,u) ->
      let eval bound = function
        | None -> bound
        | Some { Cil_types.term_node=TConst (Integer (v, _)) } -> Some v
        | Some _ -> raise Abstract_interp.Error_Top
      in
      let lb, ub = array_bounds array_size in
      let l' = eval lb l and u' = eval ub u in
      Ival.inject_range l' u'
    | _ -> raise Abstract_interp.Error_Top

  let rec of_term_offset base_typ = function
    | Cil_types.TNoOffset -> NoOffset base_typ
    | TField (fi, sub) ->
      Field (fi, of_term_offset fi.ftype sub)
    | TIndex (index, sub) ->
      begin match Cil.unrollType base_typ with
        | TArray (elem_typ, array_size, _, _) ->
          let idx = index_of_term array_size index in
          assert_valid_index idx array_size;
          Index (idx, elem_typ, of_term_offset elem_typ sub)
        | _ -> assert false
      end
    | _ -> raise Abstract_interp.Error_Top

  let rec is_singleton = function
    | NoOffset _ -> true
    | Field (_fi, sub) -> is_singleton sub
    | Index (ival, _elem_typ, sub) ->
      Ival.is_singleton_int ival && is_singleton sub
end

module TypedOffsetOrTop =
struct
  type t = [ `Value of typed_offset | `Top ]

  let pretty fmt = function
    | `Top -> Format.pp_print_string fmt "T"
    | `Value o -> TypedOffset.pretty fmt o

  let append o1 o2 =
    match o1, o2 with
    | `Top, _ | _, `Top -> `Top
    | `Value o1, `Value o2 -> `Value (TypedOffset.append o1 o2)

  let join o1 o2 =
    match o1, o2 with
    | `Top, _ | _, `Top -> `Top
    | `Value o1, `Value o2 ->
      try `Value (TypedOffset.join o1 o2)
      with Abstract_interp.Error_Top -> `Top

  let of_cil_offset oracle base_typ offset =
    try `Value (TypedOffset.of_cil_offset oracle base_typ offset)
    with Abstract_interp.Error_Top -> `Top

  let of_ival ~base_typ ~typ ival =
    try `Value (TypedOffset.of_ival ~base_typ ~typ ival)
    with Abstract_interp.Error_Top -> `Top

  let of_term_offset base_typ toffset =
    try `Value (TypedOffset.of_term_offset base_typ toffset)
    with Abstract_interp.Error_Top -> `Top

  let is_singleton = function
    | `Top -> false
    | `Value o -> TypedOffset.is_singleton o
end
