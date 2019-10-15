(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

open Cil
open Cil_types
open Cil_const
open Logic_const

let ptr_of t = TPtr(t, [])
let const_of t = Cil.typeAddAttributes [Attr("const", [])] t

let size_t () =
  Globals.Types.find_type Logic_typing.Typedef "size_t"

let prepare_definition name fun_type =
  let vi = Cil.makeGlobalVar ~referenced:true name fun_type in
  vi.vdefined <- true ;
  let fd = Cil.emptyFunctionFromVI vi in
  Cil.setFormalsDecl vi fun_type ;
  fd.sformals <- Cil.getFormalsDecl vi ;
  fd

let call_function lval vi args =
  let loc  = Cil_datatype.Location.unknown in
  let _, typs, _, _ = Cil.splitFunctionTypeVI vi in
  let typs = Cil.argsToList typs in
  let gen_arg exp (_, typ, _) =
    if Cil_datatype.Typ.equal vi.vtype typ then exp
    else Cil.mkCast exp typ
  in
  let args = List.map2 gen_arg args typs in
  Call(lval, (Cil.evar vi), args, loc)

let rec string_of_typ_aux = function
  | TInt(IBool, _) -> "bool"
  | TInt(IChar, _) -> "char"
  | TInt(ISChar, _) -> "schar"
  | TInt(IUChar, _) -> "uchar"
  | TInt(IInt, _) -> "int"
  | TInt(IUInt, _) -> "uint"
  | TInt(IShort, _) -> "short"
  | TInt(IUShort, _) -> "ushort"
  | TInt(ILong, _) -> "long"
  | TInt(IULong, _) -> "ulong"
  | TInt(ILongLong, _) -> "llong"
  | TInt(IULongLong, _) -> "ullong"
  | TFloat(FFloat, _) -> "float"
  | TFloat(FDouble, _) -> "double"
  | TFloat(FLongDouble, _) -> "ldouble"
  | TPtr(t, _) -> "ptr_" ^ string_of_typ t
  | TEnum (ei, _) -> ei.ename
  | TComp (ci, _, _) -> ci.cname
  | TArray (t, Some e, _, _) ->
    "arr" ^ (string_of_exp e) ^ "_" ^ string_of_typ t
  | _ -> assert false
and string_of_typ t = string_of_typ_aux (Cil.unrollType t)
and string_of_exp e = Format.asprintf "%a" Cil_printer.pp_exp e

let size_var t value = {
  l_var_info = make_logic_var_local "__fc_len" t;
  l_type = Some t;
  l_tparams = [];
  l_labels = [];
  l_profile = [];
  l_body = LBterm value;
}

(** Features related to terms *)

let cvar_to_tvar vi = tvar (cvar_to_lvar vi)

let tminus ?loc t1 t2 =
  let minus, typ = match t1.term_type, t2.term_type with
    | Ctype(t1), Ctype(t2) when Cil.isPointerType t1 && Cil.isPointerType t2 ->
      MinusPP, Linteger
    | Ctype(t), _ when Cil.isPointerType t ->
      MinusPI, Ctype(t)
    | t, _ ->
      MinusA, t
  in
  term ?loc (TBinOp(minus, t1, t2)) typ

let tplus ?loc t1 t2 =
  let plus = match t1.term_type with
    | Ctype(t) when Cil.isPointerType t -> PlusPI
    | _ -> PlusA
  in
  term ?loc (TBinOp(plus, t1, t2)) t1.term_type

let tdivide ?loc t1 t2 =
  term ?loc (TBinOp(Div, t1, t2)) t1.term_type

let ttype_of_pointed = function
  | Ctype(TPtr(t, _)) | Ctype(TArray(t, _, _, _)) -> Ctype t
  | _ -> assert false

let tbuffer_range ?loc ptr len =
  let last = tminus ?loc len (tinteger ?loc 1) in
  let range = trange ?loc (Some (tinteger ?loc 0), Some last) in
  tplus ?loc ptr range

let rec tunref_range ?loc ptr len =
  let typ = ttype_of_pointed ptr.term_type in
  let range = tbuffer_range ?loc ptr len in
  let tlval = (TMem range), TNoOffset in
  let tlval, typ = tunref_range_unfold ?loc tlval typ in
  term (TLval tlval) typ
and tunref_range_unfold ?loc lval typ =
  match typ with
  | Ctype(TArray(typ, Some e, _, _)) ->
    let len = Logic_utils.expr_to_term ~cast:false e in
    let last = tminus ?loc len (tinteger ?loc 1) in
    let range = trange ?loc (Some (tinteger ?loc 0), Some last) in
    let lval = addTermOffsetLval (TIndex(range, TNoOffset)) lval in
    tunref_range_unfold lval (Ctype typ)
  | _ -> lval, typ

let taccess ?loc ptr offset =
  let get_lval = function
    | TLval(lval) -> lval
    | _ -> assert false
  in
  match ptr.term_type with
  | Ctype(TPtr(_)) ->
    let address = tplus ?loc ptr offset in
    let lval = TLval(TMem(address), TNoOffset) in
    term ?loc lval (ttype_of_pointed ptr.term_type)
  | Ctype(TArray(_)) ->
    let lval = get_lval ptr.term_node in
    let lval = addTermOffsetLval (TIndex(offset, TNoOffset)) lval in
    term ?loc (TLval lval) (ttype_of_pointed ptr.term_type)
  | _ -> assert false

let tsizeofpointed ?loc = function
  | Ctype(TPtr(t, _)) | Ctype(TArray(t, _, _, _)) -> tinteger ?loc (Cil.bytesSizeOf t)
  | _ -> assert false

let tlen_div_size ?loc t bytes_len =
  let sizeof = tsizeofpointed ?loc t in
  tdivide ?loc bytes_len sizeof

(** Features related to predicates *)

let plet_len_div_size ?loc t bytes_len pred =
  let len = tlen_div_size t bytes_len in
  let len_var = size_var Linteger len in
  plet ?loc len_var (pred (tvar len_var.l_var_info))

let pgeneric_valid_buffer ?loc validity lbl ptr len =
  let buffer = tbuffer_range ?loc ptr len in
  validity ?loc (lbl, buffer)

let pgeneric_valid_len_bytes ?loc validity lbl ptr bytes_len =
  plet_len_div_size ?loc ptr.term_type bytes_len (pgeneric_valid_buffer ?loc validity lbl ptr)

let pvalid_len_bytes ?loc = pgeneric_valid_len_bytes ?loc pvalid
let pvalid_read_len_bytes ?loc = pgeneric_valid_len_bytes ?loc pvalid_read

let pcorrect_len_bytes ?loc t bytes_len =
  let sizeof = tsizeofpointed ?loc t in
  let modulo = term ?loc (TBinOp(Mod, bytes_len, sizeof)) Linteger in
  prel ?loc (Req, modulo, tinteger ?loc 0)

let pindex_bounds ?loc low value up =
  let geq_0 = prel ?loc (Rle, low, value) in
  let lt_len = prel ?loc (Rlt, value, up) in
  pand ?loc (geq_0, lt_len)

let rec punfold_all_elems_eq ?loc t1 t2 len =
  assert(Cil_datatype.Logic_type.equal t1.term_type t2.term_type) ;
  pall_elems_eq ?loc 0 t1 t2 len
and pall_elems_eq ?loc depth t1 t2 len =
  let ind = Cil_const.make_logic_var_quant ("j" ^ (string_of_int depth)) Linteger in
  let tind = tvar ind in
  let bounds = pindex_bounds ?loc (tinteger 0) tind len in
  let t1_acc = taccess ?loc t1 tind in
  let t2_acc = taccess ?loc t2 tind in
  let eq = peq_unfold ?loc (depth+1) t1_acc t2_acc in
  pforall ?loc ([ind], (pimplies ?loc (bounds, eq)))
and peq_unfold ?loc depth t1 t2 =
  match t1.term_type with
  | Ctype(TArray(_, Some len, _, _)) ->
    let len = Logic_utils.expr_to_term ~cast:false len in
    pall_elems_eq ?loc depth t1 t2 len
  | _ -> prel ?loc (Req, t1, t2)

let pseparated_memories ?loc p1 len1 p2 len2 =
  let b1 = tbuffer_range ?loc p1 len1 in
  let b2 = tbuffer_range ?loc p2 len2 in
  pseparated ?loc [ b1 ; b2 ]

let make_behavior
    ?(name=Cil.default_behavior_name)
    ?(assumes=[]) ?(requires=[]) ?(ensures=[])?(assigns=WritesAny)
    ?(alloc=FreeAllocAny) ?(extension=[])
    () =
  {
    b_name = name ;
    b_requires = requires ;
    b_assumes = assumes ;
    b_post_cond = ensures ;
    b_assigns = assigns ;
    b_allocation = alloc;
    b_extended = extension
  }

let default_comp_disj bhvs =
  let b_names = List.filter (fun b -> not (String.equal Cil.default_behavior_name b))
      (List.fold_left (fun l b -> b.b_name :: l) [] bhvs)
  in match b_names with
  | [] -> [], []
  | _  -> [b_names], [b_names]

let make_funspec bhvs ?(termination=None)
    ?(complete_disjoint=(default_comp_disj bhvs)) () =
  let complete, disjoint = complete_disjoint in
  {
    spec_behavior = bhvs ;
    spec_variant = None ;
    spec_terminates = termination ;
    spec_complete_behaviors = complete ;
    spec_disjoint_behaviors = disjoint
  }
