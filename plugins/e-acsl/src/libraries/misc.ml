(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(* ************************************************************************** *)
(** {2 Handling the E-ACSL's C-libraries, part I} *)
(* ************************************************************************** *)

let is_fc_or_compiler_builtin vi =
  Ast_info.is_frama_c_builtin vi
  ||
  Ast_attributes.(contains fc_stdlib_internal vi.vattr)
  ||
  String.starts_with ~prefix:"__builtin_" vi.vname
  ||
  (Options.Replace_libc_functions.get ()
   && Functions.Libc.has_replacement vi.vname)

let is_fc_stdlib_generated vi =
  Ast_attributes.(contains fc_stdlib_generated vi.vattr)

(* ************************************************************************** *)
(** {2 Handling \result} *)
(* ************************************************************************** *)

let result_lhost kf =
  let stmt =
    try Kernel_function.find_return kf
    with Kernel_function.No_Statement -> assert false
  in
  match stmt.skind with
  | Return(Some { enode = Lval (lhost, NoOffset) }, _) -> lhost
  | _ -> assert false

let result_vi kf = match result_lhost kf with
  | Var vi -> vi
  | Mem _ -> assert false

(* ************************************************************************** *)
(** {2 Other stuff} *)
(* ************************************************************************** *)

let strip_casts e =
  let rec aux casts e =
    match e.enode with
    | CastE(ty, e') -> aux (ty :: casts) e'
    | _ -> e, casts
  in
  aux [] e

let rec add_casts tys e =
  match tys with
  | [] -> e
  | newt :: tl ->
    let e = Cil.mkCast ~newt e in
    add_casts tl e

let cty = function
  | Ctype ty -> ty
  | lty -> Options.fatal "Expecting a C type. Got %a" Printer.pp_logic_type lty

(* Replace all trailing array subscripts of an lval with zero indices. *)
let rec shift_offsets lv loc =
  let lv, off = Cil.removeOffsetLval lv in
  match off with
  | Index _ ->
    let lv = shift_offsets lv loc in
    (* since the offset has been removed at the start of the function, add a new
       0 offset to preserve the type of the lvalue. *)
    Cil.addOffsetLval (Index (Cil.zero ~loc, NoOffset)) lv
  | NoOffset | Field _ -> Cil.addOffsetLval off lv

let rec ptr_base ~loc exp =
  match exp.enode with
  | BinOp(op, lhs, _, _) ->
    (match op with
     (* Pointer arithmetic: split pointer and integer parts *)
     | MinusPI | PlusPI -> ptr_base ~loc lhs
     (* Other arithmetic: treat the whole expression as pointer address *)
     | MinusPP | PlusA | MinusA | Mult | Div | Mod
     | BAnd | BXor | BOr | Shiftlt | Shiftrt
     | Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr -> exp)
  (* AddressOf: if it is an addressof array then replace all trailing offsets
     with zero offsets to get the base. *)
  | AddrOf lv -> Cil.mkAddrOf ~loc (shift_offsets lv loc)
  (* StartOf already points to the start of an array, return exp directly *)
  | StartOf _ -> exp
  (* Cast: strip cast and continue, then recast to original type. *)
  | CastE _ ->
    let exp, casts = strip_casts exp in
    let base = ptr_base ~loc exp in
    add_casts casts base
  | Const _ | Lval _ | UnOp _ -> exp
  | SizeOf _ | SizeOfE _ | AlignOf _ | AlignOfE _
    -> assert false

let ptr_base_and_base_addr ~loc e =
  let rec ptr_base_addr ~loc base =
    match base.enode with
    | AddrOf _ | StartOf _ | Const _ -> Cil.zero ~loc
    | Lval lv -> Cil.mkAddrOrStartOf ~loc lv
    | CastE _ -> ptr_base_addr ~loc (Cil.stripCasts base)
    | _ -> assert false
  in
  let base = ptr_base ~loc e in
  let base_addr  = ptr_base_addr ~loc base in
  base, base_addr

let is_set_of_ptr_or_array lty =
  if Ast_types.Acsl.is_plain_set lty then
    let lty = Ast_types.Acsl.set_element lty in
    Ast_types.Acsl.is_ptr lty || Ast_types.Acsl.is_array lty
  else
    false

let is_signed_int lty =
  match lty with
  | Ctype cty -> Cil.isSignedInteger cty
  | Linteger -> true
  | _ -> false

let is_bitfield_pointers lty =
  let is_bitfield_pointer = function
    | Ctype typ ->
      begin match Ast_types.C.unroll_node typ with
        | TPtr typ ->
          let attrs = Ast_types.C.get_attributes typ in
          Ast_attributes.(contains bitfield_attribute_name attrs)
        | _ ->
          false
      end
    | Ltype _ | Lvar _ | Lboolean | Linteger | Lreal | Larrow _ ->
      false
  in
  if Ast_types.Acsl.is_plain_set lty then
    is_bitfield_pointer (Ast_types.Acsl.set_element lty)
  else
    is_bitfield_pointer lty

let finite_min_and_max i = match Ival.min_and_max i with
  | Some min, Some max -> min, max
  | None, _ | _, None -> assert false

let name_of_unop = function
  | Neg -> "neg"
  | LNot -> "not"
  | BNot -> "bnot"

let name_of_binop = function
  | Lt -> "lt"
  | Gt -> "gt"
  | Le -> "le"
  | Ge -> "ge"
  | Eq -> "eq"
  | Ne -> "ne"
  | LOr -> "or"
  | LAnd -> "and"
  | BOr -> "bor"
  | BXor -> "bxor"
  | BAnd -> "band"
  | Shiftrt -> "shiftr"
  | Shiftlt -> "shiftl"
  | Mod -> "mod"
  | Div -> "div"
  | Mult -> "mul"
  | PlusA -> "add"
  | MinusA -> "sub"
  | MinusPP | MinusPI | PlusPI -> assert false

let get_loc_from_pot = function
  | Analyses_types.PoT_pred p -> p.pred_loc
  | Analyses_types.PoT_term t -> t.term_loc

let get_term_from_pot = function
  | Analyses_types.PoT_pred _ -> None
  | Analyses_types.PoT_term t -> Some t

let make_binop = Cil.mkBinOp_exn ~constfold:true

let extract_uncoerced_lval e =
  let rec aux e =
    match e.enode with
    | Lval _ -> Some e
    | CastE (_, e) -> aux e
    | _ -> None
  in
  aux e

let labels_are_all_here =
  let is_here l = l = BuiltinLabel Here in
  fun labels -> List.for_all is_here labels

let unghost_type = Ast_types.C.remove_attributes_deep ["ghost"]
