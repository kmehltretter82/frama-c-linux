(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Self

(** {2 Message categories.} *)

val summary : category
val show: category
val pointer_comparison: category
val widening : category
val partition : category
val split_return : category
val precision_settings : category
val progress : category
val callstacks : category

val thread_fixpoint : category
val thread : category
val mutex : category
val queue : category
val data_races : category
val shared_memory_zone : category
val shared_memory_mutex : category
val shared_memory_mutex_details : category
val shared_memory_by_iteration : category
val shared_memory_values : category
val global_accesses : category

val cvalue_domain: category

(** Categories for printing initial and final states of cvalue domain. *)
val initial_state : category
val final_states : category

(** {2 Debug categories.} *)

val debug_iterator : category
val debug_string_literal: category

(** {2 Warning categories.} *)

val warn_alarm: warn_category
val warn_volatile: warn_category
val warn_locals_escaping: warn_category
val warn_garbled_mix_write: warn_category
val warn_garbled_mix_assigns: warn_category
val warn_garbled_mix_summary: warn_category
val warn_builtins_missing_spec: warn_category
val warn_builtins_override: warn_category
val warn_libc_unsupported_spec : warn_category
val warn_loop_unroll_auto : warn_category
val warn_loop_unroll_partial : warn_category
val warn_missing_loop_unroll : warn_category
val warn_missing_loop_unroll_for : warn_category
val warn_signed_overflow : warn_category
val warn_invalid_assigns : warn_category
val warn_missing_assigns : warn_category
val warn_missing_assigns_result : warn_category
val warn_experimental : warn_category
val warn_unknown_size : warn_category
val warn_ensures_false : warn_category
val warn_watchpoint : warn_category
val warn_recursion : warn_category
val warn_acsl : warn_category
val warn_acsl_unsupported : warn_category
