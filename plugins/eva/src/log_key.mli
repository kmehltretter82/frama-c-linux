(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Self

(** {2 Message categories.} *)

val summary : message_category
val show: message_category
val pointer_comparison: message_category
val widening : message_category
val partition : message_category
val split_return : message_category
val precision_settings : message_category
val progress : message_category
val callstacks : message_category

val thread_fixpoint : message_category
val thread : message_category
val mutex : message_category
val queue : message_category
val data_races : message_category
val shared_memory_zone : message_category
val shared_memory_mutex : message_category
val shared_memory_mutex_details : message_category
val shared_memory_by_iteration : message_category
val shared_memory_values : message_category
val global_accesses : message_category

val cvalue_domain: message_category

(** Categories for printing initial and final states of cvalue domain. *)
val initial_state : message_category
val final_states : message_category

(** {2 Debug categories.} *)

val debug_iterator : debug_category
val debug_widen_hints : debug_category
val debug_string_literal: debug_category

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
