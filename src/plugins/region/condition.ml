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
