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

let pvalid_object ?loc ?names ?(label=Logic_const.here_label) addr =
  if Ast_types.is_logic_fun_ptr addr.term_type
  then Logic_const.pvalid_function ?loc ?names addr
  else Logic_const.pobject_pointer ?loc ?names (label, addr)

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
  let f = List.hd @@ Logic_env.find_all_logic_functions "\\validregion" in
  let te = Logic_typing.ctype_of_pointed addr.term_type in
  let size = Logic_const.tinteger ?loc @@ Fields.bytesSizeOf te in
  Logic_const.papp ?loc ?names (f,[label],[addr;size])

(* -------------------------------------------------------------------------- *)
(* --- L-Val Kinds                                                        --- *)
(* -------------------------------------------------------------------------- *)

type lkind = {
  host : varinfo option ;
  unsafe : bool ;
}

let default_kind = { host = None ; unsafe = false }

let rec kind e =
  match e.enode with
  | AddrOf lv | StartOf lv -> lkind lv
  | BinOp((PlusPI|MinusPI),p,_,_) | CastE(_,p) ->
    { (kind p) with unsafe = true }
  | _ -> default_kind

and lkind (h,o) =
  let kd = hkind h in
  if kd.unsafe || safe_offset (Cil.typeOfLhost h) o then kd
  else { kd with unsafe = true }

and hkind = function
  | Var v -> { default_kind with host = Some v }
  | Mem e -> kind e

and safe_offset t = function
  | NoOffset -> true
  | Field(fd,o) -> safe_offset fd.ftype o
  | Index(_,o) ->
    Kernel.SafeArrays.get () &&
    let n = Ast_info.direct_array_size t in
    not (Z.is_zero n) &&
    safe_offset (Ast_types.direct_element_type t) o

let rec term_kind t =
  match t.term_node with
  | TAddrOf lv | TStartOf lv -> term_lkind lv
  | TBinOp((PlusPI|MinusPI),p,_) | TCast(_,_,p) ->
    { (term_kind p) with unsafe = true }
  | _ -> default_kind

and term_lkind (h,o) =
  let kd = term_hkind h in
  if kd.unsafe || safe_term_offset (Cil.typeOfTermLval (h,TNoOffset)) o then kd
  else { kd with unsafe = true }

and term_hkind = function
  | TVar { lv_origin = (Some _ as host) } -> { default_kind with host }
  | TMem e -> term_kind e
  | _ -> default_kind

and safe_term_offset t = function
  | TNoOffset -> true
  | TField(fd,o) -> safe_term_offset (Ctype fd.ftype) o
  | TModel(fm,o) -> safe_term_offset fm.mi_field_type o
  | TIndex(_,o) ->
    Kernel.SafeArrays.get () &&
    let n = Ast_info.direct_array_size @@ Logic_utils.logicCType t in
    not (Z.is_zero n) &&
    safe_term_offset (Logic_utils.type_of_array_elem t) o

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
  if kd.unsafe then Default
  else
    match kd.host with
    | Some v ->
      condition @@
      if not readonly && Attr.is_const v
      then `False
      else allocated kinstr v
    | _ ->
      condition ~validregion:true @@
      let flags = Memory.flags node in
      if not readonly && Attr.mem `Readonly flags then `False
      else
      if Attr.mem `Dynamic flags then `Default else
      if Attr.mem `Nullable flags then `Non_null else `True

let rvalid_object kinstr node kd =
  if kd.unsafe then Default
  else
    match kd.host with
    | Some v -> condition @@ allocated kinstr v
    | _ ->
      condition ~validregion:true @@
      let flags = Memory.flags node in
      if Attr.mem `Dynamic flags then `Default else
      if Attr.mem `Nullable flags then `Non_null else `True

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
  if kd.unsafe then Default else
    match kd.host with
    | Some _ -> Residual { validregion = false ; condition = `True }
    | None ->
      condition ~validregion:true @@
      if Memory.size node mod bits = 0 then `True else `Default

(* -------------------------------------------------------------------------- *)
