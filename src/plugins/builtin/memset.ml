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

let function_name = "memset"
type key = (typ * int option)

module With_collection = struct
  module OptIntInfo = struct
    let module_name = String.capitalize_ascii "Builtin.Memset.OptInt.Datatype"
  end
  module OptInt = Datatype.Option_with_collections (Datatype.Int)(OptIntInfo)
  module MemsetKeyInfo = struct
    let module_name = String.capitalize_ascii "Builtin.Memset.Key.Datatype"
  end
  include Datatype.Pair_with_collections
      (Cil_datatype.Typ) (OptInt) (MemsetKeyInfo)
end

let presult_ptr ?loc t ptr =
  prel ?loc (Req, (tresult ?loc t), ptr)

let pset_len_bytes ?loc p1 value bytes_len =
  plet_len_div_size ?loc p1.term_type bytes_len
    (punfold_all_elems_eq_val ?loc p1 value)

let generate_requires loc ptr value len =
  let pred_name = [ "is_char_value" ] in
  let bounds = match value with
    | None -> []
    | Some value ->
      let low = (tinteger ~loc 0) in
      let up  = (tinteger ~loc 256) in
      [ { (pbounds_incl_excl ~loc low value up) with pred_name } ]
  in
  List.map new_predicate (bounds @ [
      { (pcorrect_len_bytes ~loc ptr.term_type len)    with pred_name = ["aligned_end"] } ;
      { (pvalid_len_bytes ~loc here_label ptr len)     with pred_name = ["valid_dest"] }
    ])

let generate_assigns loc t ptr value len =
  let open Extlib in
  let ptr_range = new_identified_term (tunref_range ~loc ptr len) in
  let value = list_of_opt (opt_map new_identified_term value) in
  let set = ptr_range, From value in
  let result = new_identified_term (tresult t) in
  let res = result, From [ new_identified_term ptr ] in
  Writes [ set ; res ]

let generate_ensures e loc t ptr value len =
  let pred_name = [ "set_content" ] in
  let content = match e, value with
    | None, Some value ->
      [ { (pset_len_bytes ~loc ptr value len) with pred_name } ]
    | Some 0, None -> []
    | Some 255, None -> []
    | _ -> assert false
  in
  List.map (fun p -> Normal, new_predicate p) (content @ [
      { (presult_ptr ~loc t ptr) with pred_name = [ "result"] }
    ])

let generate_spec (_t, e) { svar = vi } loc =
  let (cptr, cvalue, clen) = match Cil.getFormalsDecl vi with
    | [ ptr ; value ; len ] -> ptr, (Some value), len
    | [ ptr ; len ] -> ptr, None, len
    | _ -> assert false
  in
  let t = cptr.vtype in
  let ptr = cvar_to_tvar cptr in
  let len = cvar_to_tvar clen in
  let value = Extlib.opt_map cvar_to_tvar cvalue in
  let requires = generate_requires loc ptr value len in
  let assigns  = generate_assigns loc t ptr value len in
  let ensures  = generate_ensures e loc t ptr value len in
  make_funspec [make_behavior ~requires ~assigns ~ensures ()] ()

let type_from_arg x =
  let x = Cil.stripCasts x in
  let xt = Cil.unrollTypeDeep (Cil.typeOf x) in
  let xt = Cil.type_remove_qualifier_attributes_deep xt in
  Cil.typeOf_pointed xt

let memset_value e =
  let ff = Integer.of_int 255 in
  match (Cil.constFold false e).enode with
  | Const(CInt64(ni, _, _)) when Integer.is_zero ni -> Some 0
  | Const(CInt64(ni, _, _)) when Integer.equal ni ff -> Some 255
  | _ -> None

let well_typed_call = function
  | [ ptr ; _ ; _ ] when Cil.isCharType (type_from_arg ptr) -> true
  | [ _ ; value ; _ ] ->
    begin match memset_value value with
      | None -> false
      | Some _ -> true
    end
  | _ -> false

let key_from_call = function
  | [ ptr ; _ ; _ ] when Cil.isCharType (type_from_arg ptr) ->
    (type_from_arg ptr), None
  | [ ptr ; value ; _ ] ->
    (type_from_arg ptr), (memset_value value)
  | _ -> failwith "Call to Memset.key_from_call on an ill-typed builtin call"

let char_prototype () =
  let params = [
    ("ptr", Cil.charPtrType, []) ;
    ("value", Cil.charType, []) ;
    ("num", size_t(), [])
  ] in
  TFun (Cil.charPtrType, Some params, false, [])

let prototype_exp t =
  let params = [
    ("ptr", (ptr_of t), []) ;
    ("num", size_t(), [])
  ] in
  TFun ((ptr_of t), Some params, false, [])

let generate_prototype = function
  | t, _ when Cil.isCharType t ->
    let name = function_name ^ "_" ^ (string_of_typ t) in
    let fun_type = char_prototype () in
    name, fun_type
  | t, Some x when x = 0 || x = 255 ->
    let ext = if x = 0 then "_0" else if x = 255 then "_FF" else assert false in
    let name = function_name ^ "_" ^ (string_of_typ t) ^ ext in
    let fun_type = prototype_exp t in
    name, fun_type
  | _, _ ->
    failwith "Call to Memset.generate_prototype on an ill-typed builtin call"

let retype_args (t, e) args =
  match e, args with
  | None, [ ptr ; v ; n ] ->
    let ptr = Cil.stripCasts ptr in
    assert (Cil_datatype.Typ.equal (type_from_arg ptr) Cil.charType) ;
    [ ptr ; v ; n ]
  | Some fv, [ ptr ; v ; n ] ->
    let ptr = Cil.stripCasts ptr in
    assert (Cil_datatype.Typ.equal (type_from_arg ptr) t) ;
    assert (match memset_value v with Some x when x = fv -> true | _ -> false) ;
    [ ptr ; n ]
  | _ ->
    failwith "Call to Memset.retype_args on an ill-typed builtin call"

let args_for_original (_t , e) fd =
  match e with
  | None -> List.map Cil.evar fd.sformals
  | Some n ->
    let loc = Cil_datatype.Location.unknown in
    (List.map Cil.evar fd.sformals) @ [ Cil.integer ~loc n ]

let () = Transform.register (module struct
    module Hashtbl = With_collection.Hashtbl
    type override_key = key

    let function_name = function_name
    let well_typed_call = well_typed_call
    let key_from_call = key_from_call
    let retype_args = retype_args
    let generate_prototype = generate_prototype
    let generate_spec = generate_spec
    let args_for_original = args_for_original
  end)
