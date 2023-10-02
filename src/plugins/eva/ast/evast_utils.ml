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


(* --- Origins --- *)

let origin_exp e =
  match e.origin with
  | Exp exp -> exp
  | Lval lval -> Cil.new_exp ~loc:Cil_datatype.Location.unknown (Lval lval)
  | Built | Term _ -> invalid_arg "origin is not an expression"

let [@tail_mod_cons] rec origin_offset = function
  | NoOffset -> Cil_types.NoOffset
  | Index (e, o) -> Cil_types.Index (origin_exp e, origin_offset o)
  | Field (fi, o) -> Cil_types.Field (fi, origin_offset o)

let origin_lval lv =
  match lv.origin with
  | Lval lv -> lv
  | _ ->
    match lv.node with
    | Var v, o -> Cil_types.Var v, origin_offset o
    | Mem e, o -> Cil_types.Mem (origin_exp e), origin_offset o

let loc exp =
  match exp.origin with
  | Exp exp -> Some (exp.Cil_types.eloc)
  | Lval _ | Built | Term _ -> None


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


(* Constant folding *)

(* This function is largely based on Cil.constFold. See there for details. *)
let rec const_fold (exp: exp) : exp =
  let open Evast_builder in
  match exp.node with
  | Const (CChr c) -> integer (Cil.charConstToInt c)
  | Const (CEnum {eival = v}) -> const_fold (translate_exp v)
  | Const (CReal _ | CString _ | CInt64 _) -> exp
  | Lval lv -> mk (Lval (const_fold_lval lv))
  | AddrOf lv -> mk (AddrOf (const_fold_lval lv))
  | StartOf lv -> mk (StartOf (const_fold_lval lv))
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
        else mk (CastE (t, e'))
      with Floating_point.Float_Non_representable_as_Int64 _ ->
        mk (CastE (t, e'))
    end
  (* real -> float *)
  | Const (CReal (f,_,_)), TFloat (kind, a) when a = [] ->
    float ~kind f
  (* int -> float *)
  | Const (CInt64(i,_,_)), (TFloat (kind, a)) when a = [] ->
    let f = Integer.to_float i in
    float ~kind f
  | _, _ ->
    mk (CastE (t, e'))

and const_fold_unop op e t =
  let open Evast_builder in
  let e' = const_fold e in
  let default () = if e' == e then e else mk (UnOp (op, e', t)) in
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
        mk (Const (CReal(-.f,fk,None)))
      | _ -> default ()
    end
  (* No possible folding *)
  | _ -> default ()

and const_fold_binop op e1 e2 t =
  (* TODO: float comparisons *)
  let open Evast_builder in
  let e1' = const_fold e1 in
  let e2' = const_fold e2 in
  let default () = mk (BinOp (op, e1', e2', t)) in
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

and to_integer e =
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

and to_float e =
  match e.node with
  | Const (CReal (f,_,_)) -> Some f
  | _ -> None

let fold_to_integer e =
  to_integer (const_fold e)
