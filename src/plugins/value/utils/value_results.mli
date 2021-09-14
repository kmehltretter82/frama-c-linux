(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(** This file will ultimately contain all the results computed by Value
    (which must be moved out of Db.Value), both per stack and globally. *)


open Cil_types

val mark_kf_as_called: kernel_function -> unit
val add_kf_caller: caller:kernel_function * stmt -> kernel_function -> unit

val is_non_terminating_instr: stmt -> bool
(** Returns [true] iff there exists executions of the statement that does
    not always fail/loop (for function calls). Must be called *only* on
    statements that are instructions. *)

(** {2 Results} *)
type results

val get_results: unit -> results
val set_results: results -> unit
val merge: results -> results -> results
val change_callstacks:
  (Value_types.callstack -> Value_types.callstack) -> results -> results
(** Change the callstacks for the results for which this is meaningful.
    For technical reasons, the top of the callstack must currently
    be preserved. *)


(** {2 Summary } *)

type alarm_category =
  | Division_by_zero
  | Memory_access
  | Index_out_of_bound
  | Invalid_shift
  | Overflow
  | Uninitialized
  | Dangling
  | Nan_or_infinite
  | Float_to_int
  | Other

module AlarmsStats : Map.S with type key = alarm_category

type coverage_entry =
  { mutable reachable: int;
    mutable dead: int; }

type coverage =
  { functions: coverage_entry;
    statements: coverage_entry; }

type event_count =
  { mutable errors: int;
    mutable warnings: int; }

type statuses_entry =
  { mutable valid: int;
    mutable unknown: int;
    mutable invalid: int; }

type statuses =
  { alarms: statuses_entry;
    assertions: statuses_entry;
    preconds: statuses_entry; }

type stats =
  { coverage: coverage;
    eva_events: event_count;
    kernel_events: event_count;
    statuses: statuses;
    alarms: int AlarmsStats.t; }

(** Compute analysis statistics. *)
val compute_stats: unit -> stats

(** Prints a summary of the analysis. *)
val print_summary: unit -> unit

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
