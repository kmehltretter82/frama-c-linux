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

let taddrof ?loc tlv =
  Logic_utils.mk_logic_AddrOf ?loc tlv @@ Cil.typeOfTermLval tlv

let addrof ?loc lv = taddrof ?loc @@ Logic_utils.lval_to_term_lval lv

let pvalid ?loc ?names ?(label=Logic_const.here_label) addr =
  Logic_const.pvalid ?loc ?names (label,addr)

let pvalid_read ?loc ?names ?(label=Logic_const.here_label) addr =
  Logic_const.pvalid_read ?loc ?names (label,addr)

let pinitialized ?loc ?names ?(label=Logic_const.here_label) addr =
  Logic_const.pinitialized ?loc ?names (label,addr)

let paligned ?loc ?names addr =
  let te = Logic_typing.ctype_of_pointed addr.term_type in
  let size = Logic_const.tinteger ?loc @@ Fields.bytesSizeOf te in
  Logic_const.paligned ?loc ?names (addr,size)

(* -------------------------------------------------------------------------- *)
(* --- Valid Region Built-in                                              --- *)
(* -------------------------------------------------------------------------- *)

let l_valid_region = "\\validregion"
let is_valid_region lf = lf.l_var_info.lv_name = l_valid_region
let valid_region_builtin = ref false
let pvalid_region ?loc ?names ?(label=Logic_const.here_label) addr =
  if not (!valid_region_builtin) then
    begin
      valid_region_builtin := true ;
      Logic_builtin.register {
        bl_name = l_valid_region;
        bl_labels = [FormalLabel "A"] ;
        bl_params = [] ;
        bl_type = None ;
        bl_profile = [
          "ptr", Ctype Cil_const.voidConstPtrType ;
          "size", Linteger ;
        ];
      } ;
    end ;
  let f = List.hd @@ Logic_env.find_all_logic_functions "\\validregion" in
  let te = Logic_typing.ctype_of_pointed addr.term_type in
  let size = Logic_const.tinteger ?loc @@ Fields.bytesSizeOf te in
  Logic_const.papp ?loc ?names (f,[label],[addr;size])

(* -------------------------------------------------------------------------- *)
(* --- L-Val Kinds                                                        --- *)
(* -------------------------------------------------------------------------- *)

type lkind = {
  host : varinfo option ;
  casted : bool ;
  shifted : bool ;
}

let default_kind = { host = None ; shifted = false ; casted = false }
let rec lkind e =
  match e.enode with
  | AddrOf(h,_) | StartOf(h,_) -> hkind h
  | BinOp((PlusPI|MinusPI),p,_,_) -> { (lkind p) with shifted = true }
  | CastE(_,p) -> { (lkind p) with casted = true }
  | _ -> default_kind

and hkind = function
  | Var v -> { default_kind with host = Some v }
  | Mem e -> lkind e

let rec term_lkind t =
  match t.term_node with
  | TAddrOf(h,_) | TStartOf(h,_) -> term_hkind h
  | TBinOp((PlusPI|MinusPI),p,_) -> { (term_lkind p) with shifted = true }
  | TCast(_,_,p) -> { (term_lkind p) with casted = true }
  | _ -> default_kind

and term_hkind = function
  | TVar { lv_origin = (Some _ as host) } -> { default_kind with host }
  | TMem e -> term_lkind e
  | _ -> default_kind

(* -------------------------------------------------------------------------- *)
(* --- Side Condition Generators                                          --- *)
(* -------------------------------------------------------------------------- *)

type residual =
  | Default
  | Residual of { validregion : bool ; condition : condition }
and condition = [ `True | `False | `Non_null ]

let condition ?(validregion=false) = function
  | `Default -> Default
  | #condition as condition -> Residual { validregion ; condition }

let valid_region kd =
  not (kd.casted || kd.shifted) && Kernel.SafeArrays.get ()

(* -------------------------------------------------------------------------- *)
(* ---  Valid / ValidRead                                                 --- *)
(* -------------------------------------------------------------------------- *)

let in_scope v stmt =
  List.exists
    (fun b ->
       List.exists (Varinfo.equal v) b.blocals
    ) @@ Kernel_function.find_all_enclosing_blocks stmt

let allocated kinstr v =
  if v.vglob || v.vformal then `True else
    match kinstr with
    | Kglobal -> `Default
    | Kstmt stmt -> if in_scope v stmt then `True else `False

let rvalid ~readonly kinstr node kd =
  if kd.casted || kd.shifted then Default
  else
    match kd.host with
    | Some v ->
      condition @@
      if not readonly && Attr.is_const v then `False
      else if Kernel.SafeArrays.get () then allocated kinstr v
      else `Default
    | _ ->
      let flags = Memory.flags node in
      condition ~validregion:true @@
      if not readonly && Attr.mem `Readonly flags then `False
      else if Kernel.SafeArrays.get () then
        if Attr.mem `Dynamic flags then `Default else
        if Attr.mem `Nullable flags then `Non_null else `True
      else `Default

(* -------------------------------------------------------------------------- *)
(* ---  Initialized                                                       --- *)
(* -------------------------------------------------------------------------- *)

let rinitialized node kd =
  match kd.host with
  | Some v -> condition @@ if Attr.is_initialized v then `True else `Default
  | None ->
    condition ~validregion:true @@
    let flags = Memory.flags node in
    if Attr.mem `Garbage flags || Attr.mem `Dynamic flags
    then `Default
    else if Attr.mem `Nullable flags then `Non_null else `True

(* -------------------------------------------------------------------------- *)
(* ---  Aligned                                                           --- *)
(* -------------------------------------------------------------------------- *)

let raligned node kd ~bits =
  if kd.shifted || kd.casted then Default else
    match kd.host with
    | Some _ -> Residual { validregion = false ; condition = `True }
    | None ->
      condition ~validregion:true @@
      if Memory.size node mod bits = 0 then `True else `Default

(* -------------------------------------------------------------------------- *)
