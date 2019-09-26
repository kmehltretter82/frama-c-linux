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

open Cil_types
open Logic_const
open Basic_blocks

let function_name = "memcpy"

let pseparated_memcpy_len_bytes ?loc p1 p2 bytes_len =
  let generate len = pseparated_memories ?loc p1 len p2 len in
  plet_len_div_size ?loc p1.term_type bytes_len generate

let pcopied_memcpy ?loc p1 p2 len =
  let j = Cil_const.make_logic_var_quant "j" Linteger in
  let tj = tvar j in
  let geq_0 = prel ?loc (Rle, (tinteger 0), tj) in
  let lt_len = prel ?loc (Rlt, tj, len) in
  let bounds = pand ?loc (geq_0, lt_len) in
  let p1_j = tplus ?loc p1 tj in
  let p1_acc = term ?loc (TLval(TMem(p1_j), TNoOffset)) (ttype_of_pointed p1.term_type) in
  let p2_j = tplus ?loc p2 tj in
  let p2_acc = term ?loc (TLval(TMem(p2_j), TNoOffset)) (ttype_of_pointed p2.term_type) in
  let eq = prel ?loc (Req, p1_acc, p2_acc) in
  pforall ?loc ([j], (pimplies ?loc (bounds, eq)))

let pcopied_len_bytes ?loc p1 p2 bytes_len =
  plet_len_div_size ?loc p1.term_type bytes_len (pcopied_memcpy ?loc p1 p2)

let generate_requires loc dest src len =
  List.map new_predicate [
    { (pcorrect_len_bytes ~loc dest.term_type len)    with pred_name = ["aligned_end"] } ;
    { (pvalid_len_bytes ~loc here_label dest len)     with pred_name = ["valid_dest"] } ;
    { (pvalid_read_len_bytes ~loc here_label src len) with pred_name = ["valid_read_src"] } ;
    { (pseparated_memcpy_len_bytes ~loc dest src len) with pred_name = ["separation"] }
  ]

let generate_assigns loc t dest src len =
  let dest_range = new_identified_term (tunref_range ~loc dest len) in
  let src_range = new_identified_term(tunref_range ~loc src len) in
  let copy = dest_range, From [src_range] in
  let result = new_identified_term (tresult t) in
  let dest = new_identified_term dest in
  let res = result, From [dest] in
  Writes [ copy ; res ]

let generate_ensures loc dest src len =
  List.map (fun p -> Normal, new_predicate p) [
    { (pcopied_len_bytes ~loc dest src len) with pred_name = [ "copied"] }
  ]

let generate_spec vi loc =
  let (cdest, csrc, clen) = match Cil.getFormalsDecl vi with
    | [ dest ; src ; len ] -> dest, src, len
    | _ -> assert false
  in
  let t = cdest.vtype in
  let dest = cvar_to_tvar cdest in
  let src = cvar_to_tvar csrc in
  let len = cvar_to_tvar clen in
  let requires = generate_requires loc dest src len in
  let assigns  = generate_assigns loc t dest src len in
  let ensures  = generate_ensures loc dest src len in
  make_funspec [make_behavior ~requires ~assigns ~ensures ()] ()

let generate_prototype t =
  let name = function_name ^ "_" ^ (string_of_typ t) in
  let dt = ptr_of t in
  let st = ptr_of (const_of t) in
  let params = [
    ("dest", dt, []) ;
    ("src", st, []) ;
    ("len", size_t (), [])
  ] in
  let fun_t = TFun(dt, Some params, false, []) in
  let vi = Cil.makeGlobalVar ~referenced:true name fun_t in
  Cil.setFormalsDecl vi fun_t ;
  vi

module Table = Override_table.Make(struct
    let function_name = function_name
    let build_prototype = generate_prototype
    let build_spec = generate_spec
  end)

let type_from_parameter x =
  let x = Cil.stripCasts x in
  let xt = Cil.unrollTypeDeep (Cil.typeOf x) in
  let xt = Cil.type_remove_qualifier_attributes_deep xt in
  Cil.typeOf_pointed xt

let well_typed_parameters dest src =
  let dt = type_from_parameter dest in
  let st = type_from_parameter src in
  Cil_datatype.Typ.equal dt st

let create_call fct (dest, src, len) =
  if well_typed_parameters dest src then
    let typ = type_from_parameter dest in
    let fct = Table.get_override typ in
    let dest = Cil.stripCasts dest in
    let src = Cil.stripCasts src in
    fct, (dest, src, len)
  else
    fct, (dest, src, len)

let replace_call = function
  | Call(r, ({ enode = Lval((Var fct), NoOffset) } as e), [ dest ; src ; len ], loc) ->
    let fct, (dest, src, len) = create_call fct (dest, src, len) in
    Call(r, { e with enode = Lval((Var fct), NoOffset) }, [ dest ; src ; len ], loc)
  | Local_init(r, ConsInit(fct, [ dest ; src ; len ], Plain_func), loc) ->
    let fct, (dest, src, len) = create_call fct (dest, src, len) in
    Local_init(r, ConsInit(fct, [ dest ; src ; len ], Plain_func), loc)
  | _ -> assert false

let () = Transform.register (module struct
    let function_name = function_name
    let replace_call  = replace_call
    let get_globals   = Table.get_globals
    let mark_as_computed = Table.mark_as_computed
  end)
