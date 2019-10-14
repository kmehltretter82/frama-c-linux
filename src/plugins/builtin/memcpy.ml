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

let pcopied_len_bytes ?loc p1 p2 bytes_len =
  plet_len_div_size ?loc p1.term_type bytes_len (punfold_all_elems_eq ?loc p1 p2)

let presult_dest ?loc t dest =
  prel ?loc (Req, (tresult ?loc t), dest)

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

let generate_ensures loc t dest src len =
  List.map (fun p -> Normal, new_predicate p) [
    { (pcopied_len_bytes ~loc dest src len) with pred_name = [ "copied"] } ;
    { (presult_dest ~loc t dest)            with pred_name = [ "result"] }
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

let generate_body t fd =
  let loc  = Cil_datatype.Location.unknown in
  let rv   = Cil.makeLocalVar fd "__retres" (TPtr(t, [])) in
  let args = List.map Cil.evar fd.sformals in
  let call = Instr(call_function (Some (Var rv, NoOffset)) function_name args) in
  let ret  = Return (Some (Cil.evar rv), loc) in
  let block = Cil.mkBlock (List.map Cil.mkStmt [ call ; ret]) in
  block.blocals <- [ rv ] ;
  block

let generate_function t =
  let name = function_name ^ "_" ^ (string_of_typ t) in
  let fun_t = generate_function_type t in
  let fd = prepare_definition name fun_t in
  set_function_body fd (generate_body t fd) ;
  fd

module Table = Builtin_cache.Make(struct
    let function_name = function_name
    let build_function = generate_function
    let build_spec = generate_spec
  end)

let type_from_parameter x =
  let xt = Cil.unrollTypeDeep (Cil.typeOf x) in
  let xt = Cil.type_remove_qualifier_attributes_deep xt in
  Cil.typeOf_pointed xt

let replace_call = function
  | (_fct, [ dest ; src ; len ]) ->
    let dest = Cil.stripCasts dest in
    let src = Cil.stripCasts src in
    let dt = type_from_parameter dest in
    let st = type_from_parameter src in
    if Cil_datatype.Typ.equal dt st then
      (Table.get_varinfo dt), [ dest ; src ; len ]
    else
      let msg =
        Format.asprintf "incompatible types for %s: src:%a(%a) dest:%a(%a)"
          function_name
          Cil_printer.pp_exp dest Cil_printer.pp_typ dt
          Cil_printer.pp_exp src Cil_printer.pp_typ st
      in
      raise (Transform.Bad_typing msg)
  | (_, _) ->
    raise (Transform.Bad_typing ("Expected 3 arguments for " ^ function_name))

let () = Transform.register (module struct
    let function_name = function_name
    let replace_call  = replace_call
    let get_globals   = Table.get_globals
    let mark_as_computed = Table.mark_as_computed
  end)
