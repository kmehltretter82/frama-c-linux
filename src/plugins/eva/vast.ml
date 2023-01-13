(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2017                                               *)
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

(** Boris proposition for a new unified AST, 2017. *)

type binop_int =
  | IPlus
  | IMinus
  | IMult
  | IDiv
  | IMod
  | IShiftlt
  | IShiftrt

type binop_float =
  | FPlus
  | FMinus
  | FMult
  | FDiv

type binop_ptr =
  | PPlus
  | PMinus
  | PSub

type binop_bitwise =
  | BAnd
  | BXor
  | BOr

type cast_kind =
  | UpIdCast (** Cast is either the identity or un upcast *)
  | DowncastCheck
  (** Check that the expression evaluates to a value that fits
      in the given range, and truncate otherwise. *)
  | DowncastWrap
  (** If the value does not fit, wrap (for integer) or projects to infinity *)

(** Destination type of a finite cast *)
type cast_typ = ToInt of Eval_typ.integer_range | ToFloat of Cil_types.fkind

type vconst =
  | VCInt of Integer.t
  | VCReal of float (* TODO: real ? *)
  | VCStr of string  (* TODO: unicité ? *)
  | VCWStr of int64 list  (* TODO: unicité ? *)


type 'a exp =
  | Const of vconst * 'a
  | Lval of 'a lval * 'a
  | Unop of unop * 'a exp * 'a
  | Binop of binop * 'a exp * 'a exp * 'a
  | RealOfInt of 'a exp * 'a
  | IntOfReal of 'a exp * 'a (** truncate towards zero *)
  | Cast of cast_kind * cast_typ * 'a exp * 'a
  | AddrOf of 'a lval * 'a
  | StartOf of 'a lval * 'a

and unop =
  | UNegInt
  | UNegReal
  | ULNot
  | UBNot

and binop = (* TODO: use polymorphic variants *)
  | BInt of binop_int
  | BReal of binop_float
  | BPtr of binop_ptr
  | BBitwise of binop_bitwise
  | BComp of Abstract_interp.Comp.t

and 'a lval = 'a lhost * 'a offset

and 'a lhost =
  | Var of Cil_types.varinfo
  | Mem of 'a exp

and 'a offset =
  | NoOffset
  | Field of Cil_types.fieldinfo * 'a offset
  | Index of 'a exp * 'a offset

let fail fmt = Self.fatal ~current:true fmt

let op_to_binop_int op =
  let open Cil_types in
  match op with
  | PlusA -> IPlus
  | MinusA -> IMinus
  | Mult -> IMult
  | Div -> IDiv
  | Mod -> IMod
  | Shiftlt -> IShiftlt
  | Shiftrt -> IShiftrt
  | _ -> assert false

let op_to_binop_float op =
  let open Cil_types in
  match op with
  | PlusA -> FPlus
  | MinusA -> FMinus
  | Mult -> FMult
  | Div -> FDiv
  | _ -> assert false

let op_to_binop_bitwise op =
  match op with
  | Cil_types.BAnd -> BAnd
  | Cil_types.BOr ->  BOr
  | Cil_types.BXor -> BXor
  | _ -> assert false

let op_to_comp op =
  let open Abstract_interp.Comp in
  match op with
  | Cil_types.Eq -> Eq
  | Cil_types.Ne -> Ne
  | Cil_types.Lt -> Lt
  | Cil_types.Le -> Le
  | Cil_types.Gt -> Gt
  | Cil_types.Ge -> Ge
  | _ -> assert false

let op_to_binop_ptr op =
  let open Cil_types in
  match op with
  | PlusPI -> PPlus
  | MinusPI -> PMinus
  | MinusPP -> PSub
  | _ -> assert false

(*
let classify_as_int typ =
  let open Eval_typ in
  match classify_as_scalar typ with
  | TSInt ir | TSPtr ir -> ir
  | TSNotScalar | TSFloat _ ->
    fail "non-scalar type %a" Printer.pp_typ typ

let classify_as_float typ =
  let open Eval_typ in
  match classify_as_scalar typ with
  | TSFloat fk -> fk
  | TSNotScalar | TSInt _ | TSPtr _ ->
    fail "non-float type %a" Printer.pp_typ typ

type overflow_or_downcast = Overflow | Downcast

let handle_int_overflow ik =
  if (    ik.Eval_typ.i_signed && Kernel.SignedOverflow.get ())
  || (not ik.Eval_typ.i_signed && Kernel.UnsignedOverflow.get ())
  then DowncastCheck
  else DowncastWrap

let rec translate_exp e =
  match e.Cil_types.enode with
  (* Integer constants *)
  | Cil_types.Const (Cil_types.CInt64 _ | Cil_types.CChr _ | Cil_types.CEnum _)
  | Cil_types.SizeOf _ | Cil_types.SizeOfE _
  | Cil_types.SizeOfStr _  | Cil_types.AlignOf _ | Cil_types.AlignOfE _ -> begin
      match Cil.constFoldToInt e with
      | Some i -> Const (VCInt i, e)
      | None -> fail "invalid constant %a" Printer.pp_exp e
    end

  (* String constants *)
  | Cil_types.Const (Cil_types.CStr s) -> Const(VCStr s, e)
  | Cil_types.Const (Cil_types.CWStr w) -> Const (VCWStr w, e)

  (* Floating-point constants *)
  | Cil_types.Const (Cil_types.CReal (f, _, _)) -> Const (VCReal f, e)

  (* lvalues *)
  | Cil_types.Lval lv -> Lval (translate_lval lv, e)

  (* Unary operators *)
  | Cil_types.UnOp (op, e, typ) -> begin
      match op with
      | Cil_types.Neg -> begin
          let open Eval_typ in
          match Eval_typ.classify_as_scalar typ with
          | TSInt ir ->
            (* Integer negation may overflow on signed MIN_INT: check *)
            let ov = handle_int_overflow ir in
            Cast(ov, ToInt ir, Unop (UNegInt, translate_exp e, e), e)
          | TSFloat fk ->
            (* Floating-point negation never overflows the original type. *)
            Cast (UpIdCast, ToFloat fk, Unop (UNegReal, translate_exp e, e), e)
          | TSPtr _ | TSNotScalar ->
            fail "non-numeric type %a" Printer.pp_typ typ
        end
      | Cil_types.LNot ->
        (* LNot (!) returns something between 0 and 1, which always fit into
           typ: no checks *)
        let i = Eval_typ.ik_range Cil_types.IInt in
        Cast (UpIdCast, ToInt i, Unop (ULNot, translate_exp e, e), e)
      | Cil_types.BNot ->
        (* No alarms on bitwise operations *)
        let i = classify_as_int typ in
        Cast(DowncastWrap, ToInt i, Unop (UBNot, translate_exp e, e), e)
    end

  (* Binary operators *)
  | Cil_types.BinOp (op, e1, e2, _typ) -> begin
      let open Cil_types in
      match op, Eval_typ.classify_as_scalar (Cil.typeOf e1) with
      | (PlusA | MinusA | Mult | Div | Mod | Shiftlt | Shiftrt),
        Eval_typ.TSInt ik ->
        let op = op_to_binop_int op in
        let e' = Binop (BInt op, translate_exp e1, translate_exp e2, e) in
        let ov = handle_int_overflow ik in
        Cast (ov, ToInt ik, e', e)
      | (PlusA | MinusA | Mult | Div), Eval_typ.TSFloat fk ->
        let op = op_to_binop_float op in
        let e' = Binop (BReal op, translate_exp e1, translate_exp e2, e) in
        (* Currently we always check for infinite and NaN *)
        Cast (DowncastCheck, ToFloat fk, e', e)
      | (PlusPI | IndexPI | MinusPI), Eval_typ.TSPtr _ ->
        let op = op_to_binop_ptr op in
        (* We assume that those operations do not overflow *)
        (* TODO: or do we?? *)
        Binop (BPtr op, translate_exp e1, translate_exp e2, e)
      | MinusPP, Eval_typ.TSPtr _ ->
        let op = op_to_binop_ptr op in
        let e' = Binop (BPtr op, translate_exp e1, translate_exp e2, e) in
        (* TODO: should we check absence of overflow *)
        let ik = Eval_typ.ik_range Cil.theMachine.Cil.ptrdiffKind in
        Cast (DowncastCheck, ToInt ik, e', e)
      | (Lt | Gt | Le | Ge | Eq | Ne), _ ->
        (* Same translation as for LNot *)
        let c = op_to_comp op in
        let i = Eval_typ.ik_range Cil_types.IInt in
        let e' = Binop (BComp c, translate_exp e1, translate_exp e2, e) in
        Cast (UpIdCast, ToInt i, e', e)
      | _ -> fail "invalid binop %a" Printer.pp_exp e
    end

  (* Casts *)
  | Cil_types.CastE (typ_dst, e_src) -> begin
      let typ_src = Cil.typeOf e_src in
      let open Eval_typ in
      match classify_as_scalar typ_src, classify_as_scalar typ_dst with
      | (TSInt ir_src | TSPtr ir_src), (TSInt ir_dst | TSPtr ir_dst) ->
        let ov =
          if Eval_typ.range_inclusion ir_src ir_dst = (true, true)
          then UpIdCast
          else if (ir_dst.i_signed && Kernel.SignedDowncast.get ())
               || (not ir_dst.i_signed && Kernel.UnsignedDowncast.get ())
          then DowncastCheck
          else DowncastWrap
        in
        Cast (ov, ToInt ir_dst, translate_exp e_src, e)
      | (TSInt _ | TSPtr _), TSFloat fk_dst ->
        (* This can never produce an overflow *)
        Cast (UpIdCast, ToFloat fk_dst, RealOfInt (translate_exp e_src, e), e)
      | TSFloat _fk_src, (TSInt ir_dst | TSPtr ir_dst) ->
        (* Always check for overflow, because we are casting from a float *)
        Cast(DowncastCheck, ToInt ir_dst, IntOfReal (translate_exp e_src, e), e)
      | TSFloat fk_src, TSFloat fk_dst ->
        let ov =
          if Cil.frank fk_dst >= Cil.frank fk_src
          then UpIdCast
          else DowncastCheck (* Currently we always flag infinite *)
        in
        Cast (ov, ToFloat fk_dst, translate_exp e_src, e)
      | TSNotScalar, _ | _, TSNotScalar ->
        fail "invalid cast %a" Printer.pp_exp e
    end

  (* Addresses of lvalues *)
  | Cil_types.AddrOf lv -> AddrOf (translate_lval lv, e)
  | Cil_types.StartOf lv -> StartOf (translate_lval lv, e)

and translate_lval (h, o) = (translate_host h, translate_offset o)

and translate_host h = match h with
  | Cil_types.Var vi -> Var vi
  | Cil_types.Mem e -> Mem (translate_exp e)

and translate_offset o = match o with
  | Cil_types.NoOffset -> NoOffset
  | Cil_types.Field (fi, o) -> Field (fi, translate_offset o)
  | Cil_types.Index (e, o) -> Index (translate_exp e, translate_offset o)

let original = function
  | Const (_, o) | Lval (_, o) | Unop (_, _, o) | Binop (_, _, _, o)
  | RealOfInt (_, o) | IntOfReal (_, o) | Cast (_, _, _, o)
  | AddrOf (_, o) | StartOf (_, o) -> o


type vexp = Cil_types.exp exp
type vlval = Cil_types.exp lval

module DatatypeVexp = Datatype.Make_with_collections(struct
    include Datatype.Serializable_undefined
    type t = vexp
    let reprs = [Const (VCInt Integer.zero, List.hd Cil_datatype.Exp.reprs)]
    let name = "Vast.vexp"
    let mem_project = Datatype.never_any_project
    let hash = Hashtbl.hash
    let compare = Pervasives.compare
    let equal = Datatype.from_compare
  end)

module DatatypeVlval = Datatype.Make_with_collections(struct
    include Datatype.Serializable_undefined
    type t = vlval
    let reprs = [Var (List.hd Cil_datatype.Varinfo.reprs), NoOffset ]
    let name = "Vast.vlval"
    let mem_project = Datatype.never_any_project
    let hash = Hashtbl.hash
    let compare = Pervasives.compare
    let equal = Datatype.from_compare
  end)

(* BIG TODO *)
module VExpMap = DatatypeVexp.Map
module VLvalMap = Map.Make(struct type t = vlval let compare = compare end)


(* Computation of the inputs of an expression. *)
let rec zone_of_expr find_loc expr =
  let rec process expr = match expr with
    | Lval (lval, _) ->
      (* Dereference of an lvalue. *)
      zone_of_lval find_loc lval
    | Unop (_, e, _) | Cast (_ , _, e, _) | RealOfInt (e,_) | IntOfReal (e,_) ->
      process e
    | Binop (_, e1, e2, _) ->
      (* Binary operators. *)
      Locations.Zone.join (process e1) (process e2)
    | StartOf (lv, _) | AddrOf (lv, _) ->
      (* computation of an address: the inputs of the lvalue whose address
         is computed are read to compute said address. *)
      indirect_zone_of_lval find_loc lv
    | Const _ ->
      (* constants: nothing is read to evaluate them. *)
      Locations.Zone.bottom
  in
  process expr

(* dereference of an lvalue: first, its address must be computed,
   then its contents themselves are read *)
and zone_of_lval find_loc lval =
  let loc = find_loc lval in
  let zone = Locations.enumerate_bits (Precise_locs.imprecise_location loc) in
  Locations.Zone.join zone
    (indirect_zone_of_lval find_loc lval)

(* Computations of the inputs of a lvalue : union of the "host" part and
   the offset. *)
and indirect_zone_of_lval find_loc (lhost, offset) =
  (Locations.Zone.join
     (zone_of_lhost find_loc lhost) (zone_of_offset find_loc offset))

(* Computation of the inputs of a host. Nothing for a variable, and the
   inputs of [e] for a dereference [*e]. *)
and zone_of_lhost find_loc = function
  | Var _ -> Locations.Zone.bottom
  | Mem e -> zone_of_expr find_loc e

(* Computation of the inputs of an offset. *)
and zone_of_offset find_loc = function
  | NoOffset -> Locations.Zone.bottom
  | Field (_, o) -> zone_of_offset find_loc o
  | Index (e, o) ->
    Locations.Zone.join
      (zone_of_expr find_loc e) (zone_of_offset find_loc o)


let typeOf (e:vexp) = Cil.typeOf (original e)

let rec typeOfLval = function
  | Var vi, off -> typeOffset vi.Cil_types.vtype off
  | Mem addr, off ->
    let t = Cil.typeOf_pointed (typeOf addr) in
    typeOffset t off

and typeOfLhost = function
  | Var x -> x.Cil_types.vtype
  | Mem e -> Cil.typeOf_pointed (typeOf e)

and typeOffset basetyp = function
  | NoOffset -> basetyp
  | Index (_, o) ->
    let t = Cil.typeOf_array_elem basetyp in
    typeOffset t o
  | Field (fi, o) ->
    let baseAttrs = Cil.typeAttr basetyp in
    let attrs = Cil.filter_qualifier_attributes baseAttrs in
    let fieldType = typeOffset fi.Cil_types.ftype o in
    Cil.typeAddAttributes attrs fieldType

let vhost_to_host = function
  | Var vi -> Cil_types.Var vi
  | Mem e -> Cil_types.Mem (original e)

let rec voffset_to_offset = function
  | NoOffset -> Cil_types.NoOffset
  | Field (fi, o) -> Cil_types.Field (fi, voffset_to_offset o)
  | Index (e, o) -> Cil_types.Index (original e, voffset_to_offset o)

let vlval_to_lval (lv: vlval): Cil_types.lval =
  vhost_to_host (fst lv), voffset_to_offset (snd lv)

let pp_vlval fmt lv = Printer.pp_lval fmt (vlval_to_lval lv)
let pp_vexp fmt exp = Printer.pp_exp fmt (original exp)


let vexp_of_vlval (vlval: vlval) : vexp =
  let orig_lval = vlval_to_lval vlval in
  let orig_expr = Cil.dummy_exp (Cil_types.Lval orig_lval) in
  Lval (vlval, orig_expr)
*)
