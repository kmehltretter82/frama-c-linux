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

let taddrof ?loc tlv =
  Logic_utils.mk_logic_AddrOf ?loc tlv @@ Cil.typeOfTermLval tlv

let addrof ?loc lv = taddrof ?loc @@ Logic_utils.lval_to_term_lval lv

let pnull ?loc ?names ~eq addr =
  let null = Logic_const.term ?loc Tnull addr.term_type in
  let rel = if eq then Req else Rneq in
  Logic_const.prel ?loc ?names (rel,addr,null)

let pbounds ?loc ?names k n =
  let z = Logic_const.tinteger ?loc 0 in
  let n = Logic_const.tint ?loc n in
  let k = Logic_utils.expr_to_term ~coerce:true k in
  let inf = Logic_const.pred ?loc (Prel(Rle,z,k)) in
  let sup = Logic_const.pred ?loc (Prel(Rlt,k,n)) in
  Logic_const.pand ?loc ?names (inf,sup)

let pvalid ?loc ?names ?(label=Logic_const.here_label) addr =
  Logic_const.pvalid ?loc ?names (label,addr)

let pvalid_read ?loc ?names ?(label=Logic_const.here_label) addr =
  Logic_const.pvalid_read ?loc ?names (label,addr)

let pvalid_pointer ?loc ?names ?(label=Logic_const.here_label) addr =
  Logic_const.por ?loc ?names
    ( pnull ?loc ?names ~eq:true addr ,
      if Ast_types.is_logic_fun_ptr addr.term_type
      then Logic_const.pvalid_function ?loc ?names addr
      else Logic_const.pobject_pointer ?loc ?names (label, addr) )

let pinitialized ?loc ?names ?(label=Logic_const.here_label) addr =
  Logic_const.pinitialized ?loc ?names (label,addr)

let paligned ?loc ?names addr te =
  let size = Logic_const.term ?loc (TAlignOf te) Linteger in
  Logic_const.paligned ?loc ?names (addr,size)

(* -------------------------------------------------------------------------- *)
(* --- Valid Region Built-in                                              --- *)
(* -------------------------------------------------------------------------- *)

let l_valid_region = "\\valid_region"
let is_valid_region lf = lf.l_var_info.lv_name = l_valid_region

let () = Logic_builtin.register {
    bl_name = l_valid_region;
    bl_labels = [FormalLabel "A"] ;
    bl_params = [] ;
    bl_type = None ;
    bl_profile = [
      "ptr", Ctype Cil_const.voidConstPtrType ;
      "size", Linteger ;
    ];
  }

let pvalid_region ?loc ?names ?(label=Logic_const.here_label) addr =
  let f = List.hd @@ Logic_env.find_all_logic_functions l_valid_region in
  let te = Logic_typing.ctype_of_pointed addr.term_type in
  let size = Logic_const.term ?loc (TSizeOf te) Linteger in
  Logic_const.papp ?loc ?names (f,[label],[addr;size])

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions                                                   --- *)
(* -------------------------------------------------------------------------- *)

type addr = LV of lval | ADDR of exp

let pp_addr fmt = function
  | LV lv -> Format.fprintf fmt "&(%a)" Printer.pp_lval lv
  | ADDR p -> Printer.pp_exp fmt p

type access = Read | Write | Region | Initialized

type guard =
  | True | False
  | Or of guard * guard
  | And of guard * guard
  | Imply of guard * guard
  | Bounds of exp * Z.t
  | Null of bool * addr
  | Valid of access * Memory.node * addr

let rec pp_guard fmt = function
  | True -> Format.pp_print_string fmt "\\true"
  | False -> Format.pp_print_string fmt "\\false"
  | Or(p,q) -> Format.fprintf fmt "(@[<hov 2>%a@ || %a)@]" pp_guard p pp_guard q
  | And(p,q) -> Format.fprintf fmt "(@[<hov 2>%a@ && %a)@]" pp_guard p pp_guard q
  | Imply(p,q) -> Format.fprintf fmt "(@[<hov 2>%a@ ==> %a)@]" pp_guard p pp_guard q
  | Bounds(k,n) -> Format.fprintf fmt "0<= %a < %a" Printer.pp_exp k Z.pretty n
  | Null(eq,a) -> Format.fprintf fmt "(%a %c= \\null)" pp_addr a (if eq then '=' else '!')
  | Valid(Write,_,a) -> Format.fprintf fmt "\\valid(%a)" pp_addr a
  | Valid(Read,_,a) -> Format.fprintf fmt "\\valid_read(%a)" pp_addr a
  | Valid(Region,_,a) -> Format.fprintf fmt "\\valid_region(%a)" pp_addr a
  | Valid(Initialized,_,a) -> Format.fprintf fmt "\\initialized(%a)" pp_addr a

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

let of_addr ?loc = function
  | LV lval -> addrof ?loc lval
  | ADDR ptr -> Logic_utils.expr_to_term ~coerce:true ptr

(* Names are only set at top-level predicate *)
let rec of_guard ?loc ?names = function
  | True -> Logic_const.ptrue
  | False -> Logic_const.pfalse
  | Or(p,q) -> Logic_const.por ?loc ?names (of_guard ?loc p , of_guard ?loc q)
  | And(p,q) -> Logic_const.pand ?loc ?names (of_guard ?loc p , of_guard ?loc q)
  | Imply(p,q) -> Logic_const.pimplies ?loc ?names (of_guard ?loc p , of_guard ?loc q)
  | Bounds(k,n) -> pbounds ?loc ?names k n
  | Null(eq,a) -> pnull ?loc ?names ~eq @@ of_addr ?loc a
  | Valid(Write,_,p) -> pvalid ?loc ?names @@ of_addr ?loc p
  | Valid(Read,_,p) -> pvalid_read ?loc ?names @@ of_addr ?loc p
  | Valid(Region,_,p) -> pvalid_region ?loc ?names @@ of_addr ?loc p
  | Valid(Initialized,_,p) -> pinitialized ?loc ?names @@ of_addr ?loc p

(* -------------------------------------------------------------------------- *)
