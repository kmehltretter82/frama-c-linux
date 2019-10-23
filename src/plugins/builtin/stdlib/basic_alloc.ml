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

open Logic_const
open Cil_types

let pis_allocable ?loc size =
  let is_allocable = Logic_env.find_all_logic_functions "is_allocable" in
  let is_allocable = Extlib.as_singleton is_allocable in
  papp ?loc (is_allocable, [here_label], [size])

let is_allocable ?loc size =
  let p = pis_allocable ?loc size in
  new_predicate { p with pred_name = [ "allocable" ]}

let isnt_allocable ?loc size =
  let p = pnot ?loc (pis_allocable ?loc size) in
  new_predicate { p with pred_name = [ "allocable" ]}

let heap_status () =
  let heap_status = Globals.Vars.find_from_astinfo "__fc_heap_status" VGlobal in
  Basic_blocks.cvar_to_tvar (heap_status)

let assigns_result ?loc typ deps =
  let heap_status = new_identified_term (heap_status ()) in
  let deps = match deps with
    | [] -> []
    | l -> heap_status :: (List.map new_identified_term l)
  in
  let result = new_identified_term (tresult ?loc typ) in
  result, From deps

let assigns_heap deps =
  let heap_status = new_identified_term (heap_status ()) in
  let deps = List.map new_identified_term deps in
  heap_status, From (heap_status :: deps)

let allocates_nothing () =
  FreeAlloc([],[])

let allocates_result ?loc t =
  FreeAlloc ([], [new_identified_term (tresult ?loc t)])

let fresh_result ?loc typ size =
  let result = tresult ?loc typ in
  let p = pfresh ?loc (old_label, here_label, result, size) in
  new_predicate { p with pred_name = [ "fresh_result" ] }

let null_result ?loc typ =
  let tresult = tresult ?loc typ in
  let tnull = term ?loc Tnull (Ctype typ) in
  let p = prel ?loc (Req, tresult, tnull) in
  new_predicate { p with pred_name = [ "null_result" ] }
