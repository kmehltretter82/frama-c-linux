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

include Plugin.General_services

val proxy: State_builder.Proxy.t
val state: State.t

(** Return [true] iff the value analysis has been done. *)
val is_computed: unit -> bool

(** Computation state of the analysis. *)
type computation_state = NotComputed | Computing | Computed | Aborted

(** The current computation state of the analysis, updated by
    [force_compute] and states updates. *)
module ComputationState : State_builder.Ref with type data = computation_state

(** Debug categories responsible for printing initial and final states of Value.
    Enabled by default, but can be disabled via the command-line:
    -value-msg-key="-initial_state,-final_state" *)
val dkey_initial_state : category
val dkey_final_states : category
val dkey_summary : category

(** {2 Debug categories.} *)

val dkey_pointer_comparison: category
val dkey_cvalue_domain: category
val dkey_incompatible_states: category
val dkey_iterator : category
val dkey_callbacks : category
val dkey_widening : category
val dkey_recursion : category

(** {2 Warning categories.} *)

val wkey_alarm: warn_category
val wkey_locals_escaping: warn_category
val wkey_garbled_mix_write: warn_category
val wkey_garbled_mix_assigns: warn_category
val wkey_garbled_mix_summary: warn_category
val wkey_builtins_missing_spec: warn_category
val wkey_builtins_override: warn_category
val wkey_libc_unsupported_spec : warn_category
val wkey_loop_unroll_auto : warn_category
val wkey_loop_unroll_partial : warn_category
val wkey_missing_loop_unroll : warn_category
val wkey_missing_loop_unroll_for : warn_category
val wkey_signed_overflow : warn_category
val wkey_invalid_assigns : warn_category
val wkey_experimental : warn_category
val wkey_unknown_size : warn_category
val wkey_ensures_false : warn_category
val wkey_watchpoint : warn_category
