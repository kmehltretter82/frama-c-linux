(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

type analysis_kind = [ `Builtin | `Spec | `Body | `Reuse ]

type call_hook =
  Callstack.t -> Cil_types.kernel_function -> state -> analysis_kind -> unit

module Call =
  Hook.Build
    (struct type t = Callstack.t * kernel_function * state * analysis_kind end)

let register_call_hook f =
  Call.extend (fun (callstack, kf, kind, state) -> f callstack kf kind state)

let apply_call_hooks callstack kf state kind =
  Call.apply (callstack, kf, state, kind)

type call_assigns = (Assigns.t * Locations.Zone.t) option

type state_by_stmt = (state Cil_datatype.Stmt.Hashtbl.t) Lazy.t
type results = { before_stmts: state_by_stmt; after_stmts: state_by_stmt }

type call_results =
  [ `Builtin of state list * call_assigns
  | `Spec of state list
  | `Body of results * int
  | `Reuse of int
  ]

type call_results_hook =
  Callstack.t -> Cil_types.kernel_function -> state -> call_results -> unit

module Call_Results =
  Hook.Build
    (struct type t = Callstack.t * kernel_function * state * call_results end)

let register_call_results_hook f =
  Call_Results.extend
    (fun (callstack, kf, state, results) -> f callstack kf state results)

let apply_call_results_hooks callstack kf state call_results =
  if Parameters.ValShowProgress.get () && not (Call_Results.is_empty ())
  then Self.debug ~dkey "now calling Call_Results callbacks";
  Call_Results.apply (callstack, kf, state, call_results)


module Statement =
  Hook.Build (struct type t = Callstack.t * stmt * state list end)

let register_statement_hook f =
  Statement.extend (fun (callstack, stmt, states) -> f callstack stmt states)

let apply_statement_hooks callstack stmt states =
  Statement.apply (callstack, stmt, states)
