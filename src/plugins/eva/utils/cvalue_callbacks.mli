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

[@@@ api_start]

(** Register actions to performed during the Eva analysis,
    with access to the states of the cvalue domain.
    This API is for internal use only, and may be modified or removed
    in a future version. Please contact us if you need to register callbacks
    to be executed during an Eva analysis. *)

type state = Cvalue.Model.t

type analysis_kind =
  [ `Builtin (** A cvalue builtin is used to interpret the function. *)
  | `Spec  (** The specification is used to interpret the function. *)
  | `Def   (** The function body is analyzed. This is the standard case. *)
  | `Reuse (** The results of a previous analysis of the function are reused. *)
  ]

(** Registers a function to be applied at the beginning of the analysis of each
    function call. Arguments of the callback are the callstack of the call,
    the function called, the kind of analysis performed by Eva for this call,
    and the cvalue state at the beginning of the call. *)
val register_call_hook:
  (Callstack.t -> Cil_types.kernel_function -> state -> analysis_kind -> unit)
  -> unit


type state_by_stmt = (state Cil_datatype.Stmt.Hashtbl.t) Lazy.t
type results = { before_stmts: state_by_stmt; after_stmts: state_by_stmt }

(** Results of a function call. *)
type call_results =
  [ `Builtin of state list * Value_types.call_froms
  (** List of cvalue states at the end of the builtin. *)
  | `Spec of state list
  (** List of cvalue states at the end of the call. *)
  | `Def of results * int
  (** Cvalue states before and after each statement of the given function,
      plus a unique integer id for the call. *)
  | `Reuse of int
    (** The results are the same as a previous call with the given integer id,
        previously recorded with the [Def] constructor. *)
  ]

(** Registers a function to be applied at the end of the analysis of each
    function call. Arguments of the callback are the callstack of the call,
    the function called, the initial cvalue state at the start of the call,
    and the cvalue states resulting from its analysis. *)
val register_call_results_hook:
  (Callstack.t -> Cil_types.kernel_function -> state -> call_results -> unit)
  -> unit

[@@@ api_end]

val register_statement_hook:
  (Callstack.t -> Cil_types.stmt -> state list -> unit) -> unit

val apply_call_hooks:
  Callstack.t -> Cil_types.kernel_function -> state -> analysis_kind -> unit
val apply_call_results_hooks:
  Callstack.t -> Cil_types.kernel_function -> state -> call_results -> unit
val apply_statement_hooks:
  Callstack.t -> Cil_types.stmt -> state list -> unit
