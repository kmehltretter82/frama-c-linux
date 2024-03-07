(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

open Evast


(* --- Conversion to Cil --- *)

module ConversionToCil =
  State_builder.Hashtbl
    (Evast_datatype.Exp.Hashtbl)
    (Cil_datatype.Exp)
    (struct
      let name = "Value.Evast_utils.ConversionToCil"
      let size = 16
      let dependencies = [ Ast.self ]
    end)

let undefined_location =
  let l = { Cil_datatype.Position.unknown with
            Filepath.pos_path = Datatype.Filepath.of_string "__eva__" }
  in
  l, l

let rec to_cil_exp exp =
  match exp.origin with
  | Exp e -> e
  | _ -> ConversionToCil.memo (fun e -> build_cil_exp e.node) exp

and build_cil_exp node =
  let exp_node = match node with
    | Const c -> Cil_types.Const (to_cil_const c)
    | Lval lv -> Lval (to_cil_lval lv)
    | SizeOf (t, _) -> SizeOf (t)
    | SizeOfE (e, _) -> SizeOfE (to_cil_exp e)
    | SizeOfStr (s, _) -> SizeOfStr (s)
    | AlignOf (t, _) -> AlignOf (t)
    | AlignOfE (e, _) -> AlignOfE (to_cil_exp e)
    | UnOp (op, e, t) -> UnOp (to_cil_unop op, to_cil_exp e, t)
    | BinOp (op, e1, e2, t) ->
      BinOp (to_cil_binop op, to_cil_exp e1, to_cil_exp e2, t)
    | CastE (t, e) -> CastE (t, to_cil_exp e)
    | AddrOf (lv) -> AddrOf (to_cil_lval lv)
    | StartOf (lv) -> StartOf (to_cil_lval lv)
  in
  Cil.new_exp ~loc:undefined_location exp_node

and to_cil_unop op =
  match op with
  | Neg -> Cil_types.Neg
  | BNot -> BNot
  | LNot -> LNot

and to_cil_binop op =
  match op with
  | PlusA -> Cil_types.PlusA
  | PlusPI -> PlusPI
  | MinusA -> MinusA
  | MinusPI -> MinusPI
  | MinusPP -> MinusPP
  | Mult -> Mult
  | Div -> Div
  | Mod -> Mod
  | Shiftlt -> Shiftlt
  | Shiftrt -> Shiftrt
  | Lt -> Lt
  | Gt -> Gt
  | Le -> Le
  | Ge -> Ge
  | Eq -> Eq
  | Ne -> Ne
  | BAnd -> BAnd
  | BXor -> BXor
  | BOr -> BOr
  | LAnd -> LAnd
  | LOr -> LOr

and to_cil_lval lval =
  match lval.origin with
  | Lval lv -> lv
  | _ ->
    let (lh, off) = lval.node in
    to_cil_lh lh, to_cil_offset off

and to_cil_lh lhost =
  match lhost with
  | Var vi -> Cil_types.Var (vi)
  | Mem e -> Mem (to_cil_exp e)

and to_cil_offset offset =
  match offset with
  | NoOffset -> Cil_types.NoOffset
  | Field (fi, off) -> Field (fi, to_cil_offset off)
  | Index (e, off) -> Index (to_cil_exp e, to_cil_offset off)

and to_cil_const const =
  match const with
  | CInt64 (i, ik, s) -> Cil_types.CInt64 (i, ik, s)
  | CString (_base) -> to_cil_fail ()
  | CChr (c) -> CChr (c)
  | CReal (f, fk, s) -> CReal (f, fk, s)
  | CEnum (ei) -> CEnum (ei)

and to_cil_fail () =
  invalid_arg "this AST cannot be converted to cil"


(* --- Heights --- *)

let rec height_exp exp =
  match exp.node with
  | Const _ | SizeOf _ | SizeOfStr _ | AlignOf _ -> 0
  | Lval lv | AddrOf lv | StartOf lv  -> height_lval lv + 1
  | UnOp (_,e,_) | CastE (_, e) | SizeOfE (e,_) | AlignOfE (e,_)
    -> height_exp e + 1
  | BinOp (_,e1,e2,_) -> max (height_exp e1) (height_exp e2) + 1

and height_lval lv =
  let host, offset = lv.node in
  let h1 = match host with
    | Var _ -> 0
    | Mem e -> height_exp e + 1
  in
  max h1 (height_offset offset) + 1

and height_offset = function
  | NoOffset  -> 0
  | Field (_,r) -> height_offset r + 1
  | Index (e,r) -> max (height_exp e) (height_offset r) + 1


(* --- Relation inversion --- *)

let invert_relation : binop -> binop = function
  | Gt -> Le
  | Lt -> Ge
  | Le -> Gt
  | Ge -> Lt
  | Eq -> Ne
  | Ne -> Eq
  | _ -> assert false

let conv_relation : binop -> Abstract_interp.Comp.t =
  function
  | Eq -> Eq
  | Ne -> Ne
  | Le -> Le
  | Lt -> Lt
  | Ge -> Ge
  | Gt -> Gt
  | _ -> invalid_arg "conv_relation: must be given a comparison operator"


(* --- Specialized visitors --- *)

let iter_lvals f =
  let open Evast_visitor.Fold in
  let neutral = () and combine () () = () in
  visit_exp ~neutral ~combine {
    default with
    fold_lval = fun ~visitor lval -> f lval; default.fold_lval ~visitor lval
  }

let exp_contains_volatile, lval_contains_volatile =
  let open Evast_visitor.Fold in
  let neutral = false and combine b1 b2 = b1 || b2 in
  let fold_lval ~visitor lval =
    Cil.isVolatileType (lval.typ) || default.fold_lval ~visitor lval
  in
  let folder = { default with fold_lval } in
  visit_exp ~neutral ~combine folder, visit_lval ~neutral ~combine folder

let vars_in_exp, vars_in_lval =
  let module VarSet = Cil_datatype.Varinfo.Set in
  let open Evast_visitor.Fold in
  let neutral = VarSet.empty and combine = VarSet.union in
  let fold_lval ~visitor lval =
    let set =
      match lval.node with
      | Var vi, _ -> VarSet.singleton vi
      | Mem e, _ -> visitor.exp e
    in
    VarSet.union set (default.fold_lval ~visitor lval)
  in
  let folder = { default with fold_lval } in
  visit_exp ~neutral ~combine folder, visit_lval ~neutral ~combine folder


(* Dependencies *)

let rec deps_of_exp find_loc exp =
  let rec process exp = match exp.node with
    | Lval lval ->
      deps_of_lval find_loc lval
    | UnOp (_, e, _) | CastE (_, e) ->
      process e
    | BinOp (_, e1, e2, _) ->
      Deps.join (process e1) (process e2)
    | StartOf lv | AddrOf lv ->
      Deps.data (indirect_zone_of_lval find_loc lv)
    | Const _ | SizeOf _ | AlignOf _ | SizeOfStr _ | SizeOfE _ | AlignOfE _ ->
      Deps.bottom
  in
  process exp

and zone_of_exp find_loc exp = Deps.to_zone (deps_of_exp find_loc exp)

and deps_of_lval find_loc lval =
  let ploc = find_loc lval in
  (* dereference of an lvalue: first, its address must be computed,
     then its contents themselves are read *)
  let indirect = indirect_zone_of_lval find_loc lval in
  let data = Precise_locs.enumerate_valid_bits Read ploc in
  { Deps.data ; indirect }

and zone_of_lval find_loc lval = Deps.to_zone (deps_of_lval find_loc lval)

(* Computations of the inputs of a lvalue : union of the "host" part and
   the offset. *)
and indirect_zone_of_lval find_loc lval =
  let lhost, offset = lval.node in
  let lhost_zone = zone_of_lhost find_loc lhost
  and offset_zone = zone_of_offset find_loc offset in
  Locations.Zone.join lhost_zone offset_zone

(* Computation of the inputs of a host. Nothing for a variable, and the
   inputs of [e] for a dereference [*e]. *)
and zone_of_lhost find_loc = function
  | Var _ -> Locations.Zone.bottom
  | Mem e -> zone_of_exp find_loc e


(* Computation of the inputs of an offset. *)
and zone_of_offset find_loc = function
  | NoOffset -> Locations.Zone.bottom
  | Field (_, o) -> zone_of_offset find_loc o
  | Index (e, o) ->
    Locations.Zone.join
      (zone_of_exp find_loc e) (zone_of_offset find_loc o)

let rec to_integer e =
  match e.node with
  | Const (CInt64 (n,_,_)) -> Some n
  | Const (CChr c) -> Some (Cil.charConstToInt c)
  | Const (CEnum {eival = v}) -> Cil.isInteger v
  | CastE (typ, e) when Cil.isPointerType typ ->
    begin match to_integer e with
      | Some i as r when Cil.fitsInInt Cil.theMachine.upointKind i -> r
      | _ -> None
    end
  | _ -> None

let to_float e =
  match e.node with
  | Const (CReal (f,_,_)) -> Some f
  | _ -> None

let is_zero exp =
  match to_integer exp with
  | None -> false
  | Some i -> Integer.is_zero i

let is_zero_ptr exp =
  is_zero exp && Cil.isPointerType exp.typ


(* Constant folding *)

(* This function is largely based on Cil.constFold. See there for details. *)
let rec const_fold (exp: exp) : exp =
  let open Evast_builder in
  match exp.node with
  | Const (CChr c) -> integer (Cil.charConstToInt c)
  | Const (CEnum {eival = v}) -> const_fold (translate_exp v)
  | Const (CReal _ | CString _ | CInt64 _) -> exp
  | Lval lv -> mk_exp (Lval (const_fold_lval lv))
  | AddrOf lv -> mk_exp (AddrOf (const_fold_lval lv))
  | StartOf lv -> mk_exp (StartOf (const_fold_lval lv))
  | SizeOf (_, size_opt) | SizeOfE (_, size_opt) | SizeOfStr (_, size_opt)
  | AlignOf (_, size_opt) | AlignOfE (_, size_opt) ->
    begin match size_opt with
      | None -> exp
      | Some i ->
        integer ~kind:Cil.theMachine.kindOfSizeOf i
    end
  | CastE (t, e) -> const_fold_cast t e
  | UnOp (op, e, t) -> const_fold_unop op e t
  | BinOp (op, e1, e2, t) -> const_fold_binop op e1 e2 t

and const_fold_cast t e =
  let open Evast_builder in
  let e' = const_fold e in
  let t' = Cil.(type_remove_attributes_for_c_cast (unrollType t)) in
  let default () = if e' == e then e else mk_exp (CastE (t, e')) in
  match e'.node, t' with
  (* integer -> integer *)
  | Const (CInt64 (i,_k,_)), (TInt (ik, a) | TEnum ({ekind = ik}, a))
    when a = [] ->
    integer ~kind:ik i
  (* real -> integer *)
  | Const (CReal (f,_,_)), (TInt(kind, a) | TEnum ({ekind = kind}, a))
    when a = [] ->
    begin try
        let i = Floating_point.truncate_to_integer f in
        if Cil.fitsInInt kind i
        then integer ~kind i
        else default ()
      with Floating_point.Float_Non_representable_as_Int64 _ ->
        default ()
    end
  (* real -> float *)
  | Const (CReal (f,_,_)), TFloat (kind, a) when a = [] ->
    float ~kind f
  (* int -> float *)
  | Const (CInt64(i,_,_)), (TFloat (kind, a)) when a = [] ->
    let f = Integer.to_float i in
    float ~kind f
  | _, _ -> default ()

and const_fold_unop op e t =
  let open Evast_builder in
  let e' = const_fold e in
  let default () = if e' == e then e else mk_exp (UnOp (op, e', t)) in
  match e'.node, Cil.unrollType t with
  (* Integer operations *)
  | Const (CInt64 (i,_ik,_repr)), (TInt (ik, _) | TEnum ({ekind=ik},_)) ->
    begin match op with
      | Neg -> integer ~kind:ik (Integer.neg i)
      | BNot -> integer ~kind:ik (Integer.lognot i)
      | LNot -> if Integer.(equal i zero) then int 1 else int 0
    end
  (* Float operations*)
  | Const (CReal(f,_,_)), TFloat (fk,_) ->
    begin match op with
      | Neg ->
        let f = match fk with
          | FFloat -> Floating_point.round_to_single_precision_float f
          | FDouble | FLongDouble -> f
        in
        mk_exp (Const (CReal(-.f,fk,None)))
      | _ -> default ()
    end
  (* No possible folding *)
  | _ -> default ()

and const_fold_binop op e1 e2 t =
  (* TODO: float comparisons *)
  let open Evast_builder in
  let e1' = const_fold e1 in
  let e2' = const_fold e2 in
  let default () = mk_exp (BinOp (op, e1', e2', t)) in
  (* Can a shift operation be safely computed ? *)
  let shift_in_bounds i2 =
    try
      let size = Integer.of_int (Cil.bitsSizeOf e1'.typ) in
      Integer.(ge i2 zero && lt i2 size)
    with Cil.SizeOfError _ -> false
  in
  match Cil.unrollType t with
  (* Integer operations *)
  | TInt (kind, _) | TEnum ({ekind=kind},_) ->
    begin match op, to_integer e1', to_integer e2' with
      | PlusA, Some z, _ when Integer.is_zero z -> e2'
      | (PlusA | MinusA), _, Some z when Integer.is_zero z -> e1'
      | PlusPI, _, Some z when Integer.is_zero z -> e1'
      | MinusPI, _, Some z when Integer.is_zero z -> e1'
      | PlusA, Some i1, Some i2 ->
        integer ~kind (Integer.add i1 i2)
      | MinusA, Some i1, Some i2 ->
        integer ~kind (Integer.sub i1 i2)
      | Mult, Some i1, Some i2 ->
        integer ~kind (Integer.mul i1 i2)
      | Mult, Some z, _ when Integer.is_zero z -> e1'
      | Mult, Some i1, _ when Integer.is_one i1 -> e2'
      | Mult, _, Some z when Integer.is_zero z -> e2'
      | Mult, _, Some i2 when Integer.is_one i2 -> e1'
      | Div, Some i1, Some i2  ->
        begin
          try integer ~kind (Integer.c_div i1 i2)
          with Division_by_zero -> default ()
        end
      | Div, _, Some i2 when Integer.is_one i2 -> e1'
      | Mod, Some i1, Some i2 ->
        begin
          try integer ~kind (Integer.c_rem i1 i2)
          with Division_by_zero -> default ()
        end
      | BAnd, Some i1, Some i2 ->
        integer ~kind (Integer.logand i1 i2)
      | BAnd, Some z, _ when Integer.is_zero z -> e1'
      | BAnd, _, Some z when Integer.is_zero z -> e2'
      | BOr, Some i1, Some i2 ->
        integer ~kind (Integer.logor i1 i2)
      | BOr, Some z, _ when Integer.is_zero z -> e2'
      | BOr, _, Some z when Integer.is_zero z -> e1'
      | BXor, Some i1, Some i2 ->
        integer ~kind (Integer.logxor i1 i2)
      | Shiftlt, Some i1, Some i2 when shift_in_bounds i2 ->
        integer ~kind (Integer.shift_left i1 i2)
      | Shiftlt, Some z, _ when Integer.is_zero z -> e1'
      | Shiftlt, _, Some z when Integer.is_zero z -> e1'
      | Shiftrt, Some i1, Some i2 when shift_in_bounds i2 ->
        if Cil.isSigned kind then
          integer ~kind (Integer.shift_right i1 i2)
        else
          integer ~kind (Integer.shift_right_logical i1 i2)
      | Shiftrt, Some z, _ when Integer.is_zero z -> e1'
      | Shiftrt, _, Some z when Integer.is_zero z -> e1'
      | Eq, Some i1, Some i2 ->
        bool (Integer.equal i1 i2)
      | Ne, Some i1, Some i2 ->
        bool (not (Integer.equal i1 i2))
      | Le, Some i1, Some i2 ->
        bool (Integer.le i1 i2)
      | Ge, Some i1, Some i2 ->
        bool (Integer.ge i1 i2)
      | Lt, Some i1, Some i2 ->
        bool (Integer.lt i1 i2)
      | Gt, Some i1, Some i2 ->
        bool (Integer.gt i1 i2)
      | LAnd, Some i1, _ ->
        if Integer.is_zero i1 then zero else e2'
      | LAnd, _, Some i2 ->
        if Integer.is_zero i2 then zero else e1'
      | LOr, Some i1, _ ->
        if Integer.is_zero i1 then e2' else one
      | LOr, _, Some i2 ->
        if Integer.is_zero i2 then e1' else one
      | _ -> default ()
    end
  (* Floating-point operation *)
  | TFloat (fk, _) ->
    begin match op, to_float e1', to_float e2' with
      | PlusA, Some f1, Some f2 ->
        float ~kind:fk (f1 +. f2)
      | MinusA, Some f1, Some f2 ->
        float ~kind:fk (f1 -. f2)
      | Mult, Some f1, Some f2 ->
        float ~kind:fk (f1 *. f2)
      | Div, Some f1, Some f2 ->
        float ~kind:fk (f1 /. f2)
      | _ -> default ()
    end
  | _ -> default ()

and const_fold_lval lval =
  let lhost, offset = lval.node in
  Evast_builder.mk_lval (const_fold_lhost lhost, const_fold_offset offset)

and const_fold_lhost = function
  | Mem e -> Mem (const_fold e)
  | Var _ as host -> host

and const_fold_offset = function
  | NoOffset -> NoOffset
  | Field (fi, offset) -> Field (fi, const_fold_offset offset)
  | Index (exp, offset) -> Index (const_fold exp, const_fold_offset offset)

let fold_to_integer exp =
  to_integer (const_fold exp)


(* --- Offsets --- *)

let rec last_offset offset : offset =
  match offset with
  | NoOffset | Field(_,NoOffset) | Index(_,NoOffset) -> offset
  | Field(_,off) | Index(_,off) -> last_offset off

let is_bitfield lval =
  let (_, offset) = lval.node in
  match last_offset offset with
  | Field({fbitfield=Some _}, _) -> true
  | _ -> false
