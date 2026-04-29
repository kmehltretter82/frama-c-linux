(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Side Condition Helpers                                             --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types
open Cil_datatype

(* -------------------------------------------------------------------------- *)
(* --- Valid Region Built-in                                              --- *)
(* -------------------------------------------------------------------------- *)

let lvalid_region = "\\valid_region"
let is_valid_region lf = lf.l_var_info.lv_name = lvalid_region

let () = Logic_builtin.register {
    bl_name = lvalid_region;
    bl_labels = [FormalLabel "A"] ;
    bl_params = [] ;
    bl_type = None ;
    bl_profile = [
      "ptr", Ctype Cil_const.voidConstPtrType ;
      "size", Linteger ;
    ];
  }

let pvalid_region ?loc ?names ?(label=Logic_const.here_label) addr =
  let f = List.hd @@ Logic_env.find_all_logic_functions lvalid_region in
  let te = Logic_typing.ctype_of_pointed addr.term_type in
  let size = Logic_const.term ?loc (TSizeOf te) Linteger in
  Logic_const.papp ?loc ?names (f,[label],[addr;size])

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions                                                   --- *)
(* -------------------------------------------------------------------------- *)

type addr = LV of lval | ADDR of exp | RANGE of term * typ * term * term

let pp_addr fmt = function
  | LV lv -> Format.fprintf fmt "&(%a)" Printer.pp_lval lv
  | ADDR p -> Printer.pp_exp fmt p
  | RANGE(a,_,p,q) ->
    Format.fprintf fmt "&(%a[%a..%a])"
      Printer.pp_term a Printer.pp_term p Printer.pp_term q

type access = Read | Write | Region | Initialized

type guard =
  | True | False
  | Named of string * guard
  | Or of guard * guard
  | And of guard * guard
  | Imply of guard * guard
  | Bounds of exp * Z.t
  | Null of bool * addr
  | Valid of access * Memory.node * addr
  | Separated of addr * addr

let rec pp_guard fmt = function
  | True -> Format.pp_print_string fmt "\\true"
  | False -> Format.pp_print_string fmt "\\false"
  | Named(a,p) -> Format.fprintf fmt "%s: %a" a pp_guard p
  | Or(p,q) -> Format.fprintf fmt "(@[<hov 2>%a@ || %a)@]" pp_guard p pp_guard q
  | And(p,q) -> Format.fprintf fmt "(@[<hov 2>%a@ && %a)@]" pp_guard p pp_guard q
  | Imply(p,q) -> Format.fprintf fmt "(@[<hov 2>%a@ ==> %a)@]" pp_guard p pp_guard q
  | Bounds(k,n) -> Format.fprintf fmt "0<= %a < %a" Printer.pp_exp k Z.pretty n
  | Null(eq,a) -> Format.fprintf fmt "(%a %c= \\null)" pp_addr a (if eq then '=' else '!')
  | Valid(Write,_,a) -> Format.fprintf fmt "\\valid(%a)" pp_addr a
  | Valid(Read,_,a) -> Format.fprintf fmt "\\valid_read(%a)" pp_addr a
  | Valid(Region,_,a) -> Format.fprintf fmt "\\valid_region(%a)" pp_addr a
  | Valid(Initialized,_,a) -> Format.fprintf fmt "\\initialized(%a)" pp_addr a
  | Separated(a,b) -> Format.fprintf fmt "\\separated(%a,%a)" pp_addr a pp_addr b

let g_and p q =
  match p,q with
  | True,w | w,True -> w
  | False,_ | _,False -> False
  | _ -> And(p,q)

let g_or p q =
  match p,q with
  | True,_ | _,True -> True
  | False,w | w,False -> w
  | _ -> Or(p,q)

let g_imply p q =
  match p,q with
  | True,_ -> q
  | False,_ | _,True -> True
  | Null(eq,a) , False -> Null(not eq,a)
  | _ -> Imply(p,q)

let pointed = function
  | LV lv -> Cil.typeOfLval lv
  | ADDR p -> Ast_types.pointed_type @@ Cil.typeOf p
  | RANGE(_,t,_,_) -> t

let is_zero t =
  match t.term_node with
  | TConst(Integer(z,_)) -> Z.is_zero z
  | _ -> false

let of_addr ?loc = function
  | LV lv ->
    let lv = Logic_utils.lval_to_term_lval lv in
    Logic_utils.mk_logic_AddrOf ?loc lv @@ Cil.typeOfTermLval lv
  | ADDR ptr ->
    Logic_utils.expr_to_term ~coerce:true ptr
  | RANGE(a,_,p,q) when is_zero p && is_zero q -> a
  | RANGE(a,t,p,q) ->
    let index =
      if Term.equal p q then p
      else Logic_const.trange ?loc (Some p,Some q)
    in Logic_const.term ?loc
      (TBinOp(PlusPI,a,index))
      (Ctype (Cil_const.mk_tptr t))

(* Names are only set at top-level predicate *)
let rec of_guard ?loc ?(names=[]) = function
  | True -> Logic_const.prepend_names ~names @@ Logic_const.ptrue
  | False -> Logic_const.prepend_names ~names @@ Logic_const.pfalse
  | Named(a,p) -> of_guard ?loc ~names:(a::names) p
  | Or(p,q) -> Logic_const.por ?loc ~names (of_guard ?loc p , of_guard ?loc q)
  | And(p,q) -> Logic_const.pand ?loc ~names (of_guard ?loc p , of_guard ?loc q)
  | Imply(p,q) -> Logic_const.pimplies ?loc ~names (of_guard ?loc p , of_guard ?loc q)
  | Bounds(k,n) ->
    let z = Logic_const.tinteger ?loc 0 in
    let n = Logic_const.tint ?loc n in
    let k = Logic_utils.expr_to_term ~coerce:true k in
    let inf = Logic_const.pred ?loc (Prel(Rle,z,k)) in
    let sup = Logic_const.pred ?loc (Prel(Rlt,k,n)) in
    Logic_const.pand ?loc ~names (inf,sup)
  | Null(eq,a) ->
    let addr = of_addr ?loc a in
    let null = Logic_const.term ?loc Tnull addr.term_type in
    let rel = if eq then Req else Rneq in
    Logic_const.prel ?loc ~names (rel,addr,null)
  | Valid(Write,_,p) ->
    Logic_const.(pvalid ?loc ~names (here_label, of_addr ?loc p))
  | Valid(Read,_,p) ->
    Logic_const.(pvalid_read ?loc ~names (here_label, of_addr ?loc p))
  | Valid(Initialized,_,p) ->
    Logic_const.(pinitialized ?loc ~names (here_label, of_addr ?loc p))
  | Valid(Region,_,p) -> pvalid_region ?loc ~names @@ of_addr ?loc p
  | Separated(a,b) ->
    Logic_const.pseparated ?loc ~names [ of_addr ?loc a ; of_addr ?loc b ]

(* -------------------------------------------------------------------------- *)
