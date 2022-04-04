(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

[@@@ api_start]

type callstack = (Cil_types.kernel_function * Cil_types.kinstr) list
type state = Cvalue.Model.t

type analysis_kind =
  [ `Builtin of Value_types.call_froms
  | `Spec of Cil_types.funspec
  | `Def
  | `Memexec ]

val register_call_hook:
  (callstack -> Cil_types.kernel_function -> analysis_kind -> state -> unit)
  -> unit


type state_by_stmt = (state Cil_datatype.Stmt.Hashtbl.t) Lazy.t
type results = { before_stmts: state_by_stmt; after_stmts: state_by_stmt }

type call_results =
  | Store of results * int
  | Reuse of int

val register_call_results_hook:
  (callstack -> Cil_types.kernel_function -> call_results -> unit)
  -> unit

[@@@ api_end]

val register_statement_hook:
  (callstack -> Cil_types.stmt -> state list -> unit) -> unit

val apply_call_hooks:
  callstack -> Cil_types.kernel_function -> analysis_kind -> state -> unit
val apply_call_results_hooks:
  callstack -> Cil_types.kernel_function -> call_results -> unit
val apply_statement_hooks:
  callstack -> Cil_types.stmt -> state list -> unit
