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

open Evast_types

(* --- Constructors --- *)

let value_or f x = function
  | Some v -> v
  | None -> f x

let mk_exp ?(origin=Built) ?typ node =
  let typ = typ |> value_or Evast_typing.type_of_exp_node node in
  { node ; origin ; typ }

let mk_lval ?(origin=Built) ?typ node =
  let typ = typ |> value_or Evast_typing.type_of_lval_node node in
  { node ; origin ; typ }


(* --- Translation from Cil --- *)

let translate_unop = function
  | Cil_types.Neg -> Neg
  | Cil_types.BNot -> BNot
  | Cil_types.LNot -> LNot

let translate_binop = function
  | Cil_types.PlusA -> PlusA
  | Cil_types.PlusPI -> PlusPI
  | Cil_types.MinusA -> MinusA
  | Cil_types.MinusPI -> MinusPI
  | Cil_types.MinusPP -> MinusPP
  | Cil_types.Mult -> Mult
  | Cil_types.Div -> Div
  | Cil_types.Mod -> Mod
  | Cil_types.Shiftlt -> Shiftlt
  | Cil_types.Shiftrt -> Shiftrt
  | Cil_types.Lt -> Lt
  | Cil_types.Gt -> Gt
  | Cil_types.Le -> Le
  | Cil_types.Ge -> Ge
  | Cil_types.Eq -> Eq
  | Cil_types.Ne -> Ne
  | Cil_types.BAnd -> BAnd
  | Cil_types.BXor -> BXor
  | Cil_types.BOr -> BOr
  | Cil_types.LAnd -> LAnd
  | Cil_types.LOr -> LOr


let rec translate_exp e =
  let node = match e.Cil_types.enode with
    | Cil_types.Const (Cil_types.CStr _ | Cil_types.CWStr _) ->
      Const (CString (Base.of_string_exp e))
    | Cil_types.Const cst -> Const (translate_constant cst)
    | Cil_types.Lval lval -> Lval (translate_lval lval)
    | Cil_types.UnOp (unop, expr, typ) ->
      UnOp (translate_unop unop, translate_exp expr, typ)
    | Cil_types.BinOp (binop, e1, e2, typ) ->
      BinOp (translate_binop binop, translate_exp e1, translate_exp e2, typ)
    | Cil_types.CastE (typ, expr) -> CastE (typ, translate_exp expr)
    | Cil_types.AddrOf lval -> AddrOf (translate_lval lval)
    | Cil_types.StartOf lval -> StartOf (translate_lval lval)
    | Cil_types.(SizeOf _ | SizeOfE _ | SizeOfStr _ | AlignOf _ | AlignOfE _) ->
      match (Cil.constFold true e).enode with
      | Const c -> Const (translate_constant c)
      | _ -> Const (CTopInt Cil.theMachine.typeOfSizeOf)
  in
  mk_exp ~origin:(Exp e) node

and translate_host = function
  | Cil_types.Var vi -> Var vi
  | Cil_types.Mem e -> Mem (translate_exp e)

and translate_offset = function
  | Cil_types.NoOffset -> NoOffset
  | Cil_types.Index (expr, offset) ->
    Index (translate_exp expr, translate_offset offset)
  | Cil_types.Field (fieldinfo, offset) ->
    Field (fieldinfo, translate_offset offset)

and translate_lval (host, offset as lval) =
  let node = translate_host host, translate_offset offset in
  mk_lval ~origin:(Lval lval) node

and translate_constant = function
  | Cil_types.CStr _ | Cil_types.CWStr _ -> assert false (* Handled at higher level by translate_expr *)
  | Cil_types.CInt64 (cst, ikind, str) -> CInt64 (cst, ikind, str)
  | Cil_types.CChr chr -> CChr chr
  | Cil_types.CReal (float, fkind, str) -> CReal (float, fkind, str)
  | Cil_types.CEnum ei -> CEnum (ei, translate_exp ei.eival)

let rec translate_init = function
  | Cil_types.SingleInit e -> SingleInit (translate_exp e, e.eloc)
  | Cil_types.CompoundInit (t, l) ->
    let translate_field_init (o, i) =
      translate_offset o, translate_init i
    in
    CompoundInit (t, List.map translate_field_init l)


(* --- Relations --- *)

let invert_relation : binop -> binop = function
  | Gt -> Le
  | Lt -> Ge
  | Le -> Gt
  | Ge -> Lt
  | Eq -> Ne
  | Ne -> Eq
  | _ -> invalid_arg "invert_relation: must be given a comparison operator"

let conv_relation : binop -> Abstract_interp.Comp.t =
  function
  | Eq -> Eq
  | Ne -> Ne
  | Le -> Le
  | Lt -> Lt
  | Ge -> Ge
  | Gt -> Gt
  | _ -> invalid_arg "conv_relation: must be given a comparison operator"


(* --- Offsets --- *)

let rec concat_offset (o1 : offset) (o2 : offset) : offset =
  match o1 with
  | NoOffset -> o2
  | Field (fid, o1') -> Field(fid, concat_offset o1' o2)
  | Index (e, o1') -> Index(e, concat_offset o1' o2)

let add_offset (lval : lval) (offset : offset) : lval =
  let (lval_host, lval_offset) = lval.node in
  mk_lval (lval_host, concat_offset lval_offset offset)


(* --- Smart constructors --- *)

module Build =
struct
  let integer ?kind i = (* TODO: mathematical unbounded integer *)
    let kind = match kind with
      | Some k -> k
      | None ->
        if Cil.fitsInInt IInt i
        then Cil_types.IInt
        else Cil.intKindForValue i false
    in
    let i', _truncated = Cil.truncateInteger64 kind i in
    mk_exp (Const (CInt64 (i', kind, None)))

  let int ?kind i =
    integer ?kind (Integer.of_int i)

  let zero = int 0
  let one = int 1
  let bool = function false -> zero | true -> one

  let float ~kind f =
    let f =
      if kind = Cil_types.FFloat
      then Floating_point.round_to_single_precision_float f
      else f
    in
    mk_exp (Const (CReal(f,kind,None)))

  let cast typ exp =
    if Cil.need_cast exp.typ typ
    then mk_exp (CastE (Cil.type_remove_qualifier_attributes typ, exp))
    else exp

  let binop op e1 e2 =
    (* TODO: const folding *)
    match op with
    | PlusA | MinusA | Mult | Div ->
      let t = Cil.arithmeticConversion e1.typ e2.typ in
      mk_exp (BinOp (op,e1,e2,t))

    | Eq | Ne | Lt | Le | Ge |Gt ->
      let t =
        if Cil.isArithmeticType e1.typ && Cil.isArithmeticType e2.typ then
          Cil.arithmeticConversion e1.typ e2.typ
        else if Cil.isPointerType e1.typ && Cil.isPointerType e2.typ then
          if Cil.need_cast ~force:true e1.typ e2.typ then
            Cil.theMachine.upointType
          else
            e1.typ
        else
          invalid_arg "unsupported construction"
      in
      mk_exp (BinOp (op, cast t e1, cast t e2, Cil.intType))

    | _ -> invalid_arg "unsupported construction"

  let add = binop PlusA
  let eq = binop Eq
  let ne = binop Ne

  let index (base : lval) (index : exp) : lval =
    assert(Cil.isArrayType base.typ);
    add_offset base (Index (index, NoOffset))

  let field (base : lval) (field : Cil_types.fieldinfo) : lval =
    let field_belongs_to_typ fi typ =
      match typ with
      | Cil_types.TComp (ci,_attr) -> ci == fi.Cil_types.fcomp
      | _ -> false
    in
    assert(field_belongs_to_typ field base.typ);
    add_offset base (Field (field, NoOffset))

  let addr (lval : lval) : exp =
    mk_exp (AddrOf lval)

  let mem (exp : exp) : lval =
    match exp.node with
    | AddrOf lv -> lv
    | StartOf lv -> index lv zero (* Must be an array *)
    | _ -> mk_lval (Mem exp, NoOffset)

  let var vi = mk_lval (Var vi, NoOffset)
  let var_exp vi = mk_exp (Lval (var vi))

  let lval lv = { lv with node=Lval lv }
end


(* --- Condition normalization --- *)

let zero_typed (typ : Cil_types.typ) =
  match typ with
  | TFloat (fk, _) -> mk_exp (Const (CReal (0., fk, None)))
  | TEnum ({ekind = ik },_)
  | TInt (ik, _) -> mk_exp (Const (CInt64 (Integer.zero, ik, None)))
  | TPtr _ ->
    let ik = Cil.(theMachine.upointKind) in
    let zero = mk_exp (Const (CInt64 (Integer.zero, ik, None))) in
    Build.cast typ zero
  | typ ->
    Self.fatal ~current:true "non-scalar type %a" Printer.pp_typ typ

(* Transform an expression supposed to be [positive] into an equivalent
   one in which the root expression is a comparison operator. *)
let rec normalize_condition exp positive =
  match exp.node with
  | UnOp (LNot, e, _) -> normalize_condition e (not positive)
  | BinOp ((Le|Ne|Eq|Gt|Lt|Ge as binop), e1, e2, typ) ->
    if positive
    then exp
    else mk_exp (BinOp (invert_relation binop, e1, e2, typ))
  | _ ->
    let op = if positive then Ne else Eq in
    let typ = Cil.unrollType exp.typ in
    mk_exp (BinOp (op, zero_typed typ, exp, Cil.intType))


(* --- Hide mk optional paremeters --- *)

let mk_exp = mk_exp ~origin:Built ?typ:None
let mk_lval = mk_lval ~origin:Built ?typ:None
