(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

let unexpected = Options.fatal "String.Memcpy: unexpected: %s"

let pseparated_memcpy_len_bytes ?loc p1 p2 bytes_len =
  let generate len = pseparated_memories ?loc p1 len p2 len in
  plet_len_div_size ?loc p1.term_type bytes_len generate

let pcopied_len_bytes ?loc p1 p2 bytes_len =
  plet_len_div_size ?loc p1.term_type bytes_len
    (punfold_all_elems_eq ?loc p1 p2)

let presult_dest ?loc t dest =
  prel ?loc (Req, (tresult ?loc t), dest)

let generate_requires loc dest src len =
  List.map new_predicate [
    { (pcorrect_len_bytes ~loc dest.term_type len)
      with pred_name = ["aligned_end"] } ;
    { (pvalid_len_bytes ~loc here_label dest len)
      with pred_name = ["valid_dest"] } ;
    { (pvalid_read_len_bytes ~loc here_label src len)
      with pred_name = ["valid_read_src"] } ;
    { (pseparated_memcpy_len_bytes ~loc dest src len)
      with pred_name = ["separation"] }
  ]

let generate_assigns loc t dest src len =
  let dest_range = new_identified_term (tunref_range_bytes_len ~loc dest len) in
  let src_range = new_identified_term(tunref_range_bytes_len ~loc src len) in
  let copy = dest_range, From [src_range] in
  let result = new_identified_term (tresult t) in
  let dest = new_identified_term dest in
  let res = result, From [dest] in
  Writes [ copy ; res ]

let generate_ensures loc t dest src len =
  List.map (fun p -> Normal, new_predicate p) [
    { (pcopied_len_bytes ~loc dest src len) with pred_name = [ "copied"] } ;
    { (presult_dest ~loc t dest)            with pred_name = [ "result"] }
  ]

let generate_spec _t { svar = vi } loc =
  let (cdest, csrc, clen) = match Cil.getFormalsDecl vi with
    | [ dest ; src ; len ] -> dest, src, len
    | _ -> unexpected "ill-formed fundec in specification generation"
  in
  let t = cdest.vtype in
  let dest = cvar_to_tvar cdest in
  let src = cvar_to_tvar csrc in
  let len = cvar_to_tvar clen in
  let requires = generate_requires loc dest src len in
  let assigns  = generate_assigns loc t dest src len in
  let ensures  = generate_ensures loc t dest src len in
  make_funspec [make_behavior ~requires ~assigns ~ensures ()] ()

let generate_function_type t =
  let dt = ptr_of t in
  let st = ptr_of (const_of t) in
  let params = [
    ("dest", dt, []) ;
    ("src", st, []) ;
    ("len", size_t (), [])
  ] in
  TFun(dt, Some params, false, [])

let generate_prototype t =
  let fun_type = generate_function_type t in
  let name = function_name ^ "_" ^ (string_of_typ t) in
  name, fun_type

let type_from_arg x =
  let x = Cil.stripCasts x in
  let xt = Cil.unrollTypeDeep (Cil.typeOf x) in
  let xt = Cil.type_remove_qualifier_attributes_deep xt in
  Cil.typeOf_pointed xt

let well_typed_call _ret = function
  | [ dest ; src ; len ] ->
    (Cil.isIntegralType (Cil.typeOf len)) &&
    (Cil_datatype.Typ.equal (type_from_arg dest) (type_from_arg src)) &&
    (not (Cil.isVoidType (type_from_arg dest))) &&
    (Cil.isCompleteType (type_from_arg dest))
  | _ -> false

let key_from_call _ret = function
  | [ dest ; _ ; _ ] -> type_from_arg dest
  | _ -> unexpected "trying to generate a key on an ill-typed call"

let retype_args override_key = function
  | [ dest ; src ; len ] ->
    let dest = Cil.stripCasts dest in
    let src = Cil.stripCasts src in
    assert (
      Cil_datatype.Typ.equal (type_from_arg dest) override_key &&
      Cil_datatype.Typ.equal (type_from_arg src) override_key
    ) ;
    [ dest ; src ; len ]
  | _ -> unexpected "trying to retype arguments on an ill-typed call"

let args_for_original _t args = args

let () = Transform.register (module struct
    module Hashtbl = Cil_datatype.Typ.Hashtbl
    type override_key = typ

    let function_name = function_name
    let well_typed_call = well_typed_call
    let key_from_call = key_from_call
    let retype_args = retype_args
    let generate_prototype = generate_prototype
    let generate_spec = generate_spec
    let args_for_original = args_for_original
  end)
