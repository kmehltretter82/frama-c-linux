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

let function_name = "memcmp"

let generate_requires loc s1 s2 len =
  List.map new_predicate [
    { (pcorrect_len_bytes ~loc s1.term_type len)     with pred_name = ["aligned_end"] } ;
    { (pvalid_read_len_bytes ~loc here_label s1 len) with pred_name = ["valid_read_s1"] } ;
    { (pvalid_read_len_bytes ~loc here_label s2 len) with pred_name = ["valid_read_s2"] } ;
  ]

let presult_memcmp ?loc p1 p2 len =
  let eq = punfold_all_elems_eq ?loc p1 p2 len in
  let res = prel ?loc (Req, (tresult ?loc Cil.intType), (tinteger ?loc 0)) in
  piff ?loc (res, eq)

let generate_assigns loc t s1 s2 len =
  let indirect_range loc s len =
    let t = { (tunref_range ~loc s len) with term_name = ["indirect"] } in
    new_identified_term t
  in
  let s1_range = indirect_range loc s1 len in
  let s2_range = indirect_range loc s2 len in
  let result = new_identified_term (tresult t) in
  let res = result, From [s1_range ; s2_range] in
  Writes [ res ]

let presult_memcmp_len_bytes ?loc p1 p2 bytes_len =
  plet_len_div_size ?loc p1.term_type bytes_len (presult_memcmp ?loc p1 p2)

let generate_ensures loc s1 s2 len =
  List.map (fun p -> Normal, new_predicate p) [
    { (presult_memcmp_len_bytes ~loc s1 s2 len) with pred_name = [ "equals" ] }
  ]

let generate_spec vi loc =
  let (c_s1, c_s2, clen) = match Cil.getFormalsDecl vi with
    | [ s1 ; s2 ; len ] -> s1, s2, len
    | _ -> assert false
  in
  let t = c_s1.vtype in
  let s1 = cvar_to_tvar c_s1 in
  let s2 = cvar_to_tvar c_s2 in
  let len = cvar_to_tvar clen in
  let requires = generate_requires loc s1 s2 len in
  let assigns  = generate_assigns loc t s1 s2 len in
  let ensures  = generate_ensures loc s1 s2 len in
  make_funspec [make_behavior ~requires ~assigns ~ensures ()] ()

let generate_prototype t =
  let name = function_name ^ "_" ^ (string_of_typ t) in
  let t = ptr_of (const_of t) in
  let params = [
    ("s1", t, []) ;
    ("s2", t, []) ;
    ("len", size_t (), [])
  ] in
  let fun_t = TFun(Cil.intType, Some params, false, []) in
  let vi = Cil.makeGlobalVar ~referenced:true name fun_t in
  Cil.setFormalsDecl vi fun_t ;
  vi

module Table = Builtin_cache.Make(struct
    let function_name = function_name
    let build_prototype = generate_prototype
    let build_spec = generate_spec
  end)

let type_from_parameter x =
  let x = Cil.stripCasts x in
  let xt = Cil.unrollTypeDeep (Cil.typeOf x) in
  let xt = Cil.type_remove_qualifier_attributes_deep xt in
  Cil.typeOf_pointed xt

let well_typed_parameters s1 s2 =
  let s1_t = type_from_parameter s1 in
  let s2_t = type_from_parameter s2 in
  Cil_datatype.Typ.equal s1_t s2_t

let create_call fct (s1, s2, len) =
  if well_typed_parameters s1 s2 then
    let typ = type_from_parameter s1 in
    let fct = Table.get_function typ in
    let s1 = Cil.stripCasts s1 in
    let s2 = Cil.stripCasts s2 in
    fct, (s1, s2, len)
  else
    fct, (s1, s2, len)

let replace_call = function
  | Call(r, ({ enode = Lval((Var fct), NoOffset) } as e), [ s1 ; s2 ; len ], loc) ->
    let fct, (s1, s2, len) = create_call fct (s1, s2, len) in
    Call(r, { e with enode = Lval((Var fct), NoOffset) }, [ s1 ; s2 ; len ], loc)
  | Local_init(r, ConsInit(fct, [ s1 ; s2 ; len ], Plain_func), loc) ->
    let fct, (s1, s2, len) = create_call fct (s1, s2, len) in
    Local_init(r, ConsInit(fct, [ s1 ; s2 ; len ], Plain_func), loc)
  | _ -> assert false

let () = Transform.register (module struct
    let function_name = function_name
    let replace_call  = replace_call
    let get_globals   = Table.get_globals
    let mark_as_computed = Table.mark_as_computed
  end)
