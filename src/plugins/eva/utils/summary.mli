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

type coverage =
  { mutable reachable: int;
    mutable dead: int; }

type statuses =
  { mutable valid: int;
    mutable unknown: int;
    mutable invalid: int; }

type events =
  { mutable errors: int;
    mutable warnings: int; }

type alarms = (alarm_category * int) list (* Alarm count for each category *)

type fun_stats =
  { fun_coverage: coverage;
    fun_alarm_count: alarms;
    fun_alarm_statuses: statuses; }

type program_stats =
  { prog_fun_coverage: coverage;
    prog_stmt_coverage: coverage;
    prog_alarms: alarms;
    eva_events: events;
    kernel_events: events;
    alarms_statuses: statuses;
    assertions_statuses: statuses;
    preconds_statuses: statuses; }

module FunctionStats :
sig
  type key = Kernel_function.t
  type data = fun_stats

  (** Get the current analysis statistics for a function *)
  val get: key -> data option

  (** Iterate on every function statistics *)
  val iter: (key -> data -> unit) -> unit

  (** Trigger the recomputation of function stats *)
  val recompute: key -> unit

  (** Set a hook on function statistics computation *)
  val add_hook_on_change:
    ((key, data) State_builder.hashtbl_event -> unit) -> unit
end

(** Compute analysis statistics. *)
val compute_stats: unit -> program_stats

(** Prints a summary of the analysis. *)
val print_summary: unit -> unit
