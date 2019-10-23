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

open Basic_blocks
open Cil_types
open Logic_const

let function_name = "malloc"

let fc_heap_status () =
  Globals.Vars.find_from_astinfo "__fc_heap_status" VGlobal

let generate_requires loc ptr_type len =
  [ new_predicate
      { (pcorrect_len_bytes ~loc ptr_type len)
        with pred_name = ["aligned_end"] } ]

let generate_global_assigns loc ptr_type len =
  let len = new_identified_term len in
  let res = new_identified_term (tresult ~loc ptr_type) in
  let hs  = new_identified_term (cvar_to_tvar (fc_heap_status ())) in
  let assigns_result = res, From [ len ; hs ] in
  let assigns_heap   = hs, From [ len ; hs ] in
  Writes [ assigns_result ; assigns_heap ]

let is_allocable loc len =
  pallocable ~loc (here_label, len)

let allocation_assumes loc len =
  [ new_predicate (is_allocable loc len) ]

let allocation loc ptr_type =
  FreeAlloc ([], [new_identified_term (tresult ~loc ptr_type)])

let allocation_ensures loc ptr_type len =
  let result = tresult ~loc ptr_type in
  let fresh = pfresh ~loc (old_label, here_label, result, len) in
  [ Normal, new_predicate fresh ]

let make_behavior_allocation loc ptr_type len =
  let assumes = allocation_assumes loc len in
  let assigns = generate_global_assigns loc ptr_type len in
  let alloc   = allocation loc ptr_type in
  let ensures = allocation_ensures loc ptr_type len in
  make_behavior ~name:"allocation" ~assumes ~assigns ~alloc ~ensures ()

let no_allocation_assumes loc len =
  [ new_predicate (pnot ~loc (is_allocable loc len)) ]

let no_allocation_result loc ptr_type =
  let tresult = tresult ~loc ptr_type in
  let tnull = term ~loc Tnull (Ctype ptr_type) in
  [ Normal, new_predicate (prel ~loc (Req, tresult, tnull)) ]

let make_behavior_no_allocation loc ptr_type len =
  let assumes = no_allocation_assumes loc len in
  let assigns = Writes [new_identified_term (tresult ~loc ptr_type), From []] in
  let ensures = no_allocation_result loc ptr_type in
  let alloc = FreeAlloc([],[]) in
  make_behavior ~name:"no_allocation" ~assumes ~assigns ~ensures ~alloc ()

let generate_spec alloc_typ { svar = vi } loc =
  let (clen) = match Cil.getFormalsDecl vi with
    | [ len ] -> len
    | _ -> assert false
  in
  let len = tlogic_coerce ~loc (cvar_to_tvar clen) Linteger in
  let requires = generate_requires loc (Ctype (ptr_of alloc_typ)) len in
  let assigns = generate_global_assigns loc (ptr_of alloc_typ) len in
  let alloc = allocation loc (ptr_of alloc_typ) in
  make_funspec [
    make_behavior ~requires ~assigns ~alloc () ;
    make_behavior_allocation loc (ptr_of alloc_typ) len ;
    make_behavior_no_allocation loc (ptr_of alloc_typ) len
  ] ()

let generate_prototype alloc_t =
  let name = function_name ^ "_" ^ (string_of_typ alloc_t) in
  let params = [
    ("len", size_t (), [])
  ] in
  name, (TFun((ptr_of alloc_t), Some params, false, []))

let well_typed_call ret args =
  match ret, args with
  | Some ret, [ _ ] -> Cil.isPointerType (Cil.typeOfLval ret)
  | _ -> false

let key_from_call ret _ =
  match ret with
  | Some ret ->
    let ret_t = Cil.unrollTypeDeep (Cil.typeOfLval ret) in
    let ret_t = Cil.type_remove_qualifier_attributes_deep ret_t in
    Cil.typeOf_pointed ret_t
  | None -> assert false

let retype_args _typ args = args
let args_for_original _typ fd =
  List.map Cil.evar fd.sformals

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
