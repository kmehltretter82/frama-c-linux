(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

let dkey = Self.dkey_callbacks

type state = Cvalue.Model.t

type analysis_kind =
  [ `Builtin of Value_types.call_froms
  | `Spec of funspec
  | `Def
  | `Memexec ]

module Call =
  Hook.Build
    (struct type t = Callstack.t * kernel_function * analysis_kind * state end)

let register_call_hook f =
  Call.extend (fun (callstack, kf, kind, state) -> f callstack kf kind state)

let apply_call_hooks callstack kf kind state =
  Call.apply (callstack, kf, kind, state);
  Db.Value.Call_Type_Value_Callbacks.apply (kind, state, callstack)


type state_by_stmt = (state Cil_datatype.Stmt.Hashtbl.t) Lazy.t
type results = { before_stmts: state_by_stmt; after_stmts: state_by_stmt }

type call_results =
  | Store of results * int
  | Reuse of int

module Call_Results =
  Hook.Build (struct type t = Callstack.t * kernel_function * call_results end)

let register_call_results_hook f =
  Call_Results.extend (fun (callstack, kf, results) -> f callstack kf results)

let apply_call_results_hooks callstack kf call_results =
  if Parameters.ValShowProgress.get ()
  && not (Call_Results.is_empty ()
          && Db.Value.Record_Value_Callbacks_New.is_empty ())
  then Self.debug ~dkey "now calling Call_Results callbacks";
  Call_Results.apply (callstack, kf, call_results);
  let results =
    match call_results with
    | Reuse i -> Value_types.Reuse i
    | Store ({before_stmts; after_stmts}, i) ->
      Value_types.NormalStore ((before_stmts, after_stmts), i)
  in
  Db.Value.Record_Value_Callbacks_New.apply (callstack, results)


module Statement =
  Hook.Build (struct type t = Callstack.t * stmt * state list end)

let register_statement_hook f =
  Statement.extend (fun (callstack, stmt, states) -> f callstack stmt states)

let apply_statement_hooks callstack stmt states =
  Statement.apply (callstack, stmt, states);
  Db.Value.Compute_Statement_Callbacks.apply (stmt, callstack, states)
