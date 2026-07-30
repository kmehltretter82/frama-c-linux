(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Self

(* ----- Message categories ------------------------------------------------- *)

(* Each message category is automatically enabled at a given level of verbosity:
   0: No messages.
   1: Minimal general info (starting analysis, etc) and summary.
   2: Directives given by user: Frama_C_show_each, split, etc.
   3-4: Important information about the analysis: partitioning, imprecisions…
   5: Initial and final states.
   6-8: Advanced information about automatic behaviors.
   9: Additional information such as callstacks in messages.
   10: Progress of the analysis (equivalent to -eva-show-progress).
   11: All messages (except debug messages).
*)

let callstacks = Self.key_callstacks

let show =
  register_category "show" ~level:2
    ~help:"show values/states inferred by the analysis on directives \
           such as Frama_C_show_each and Frama_C_dump_each"

let initial_state =
  register_category "initial-state" ~level:5
    ~help:"at the start of the analysis, \
           print the initial value of global variables"

let final_states =
  register_category "final-states" ~level:5
    ~help:"at the end of the analysis, print final values inferred \
           at the return point of each analyzed function "

let summary =
  register_category "summary" ~level:1
    ~help:"print a summary of the analysis at the end, including coverage \
           and alarm numbers"

let pointer_comparison =
  register_category "pointer-comparison" ~level:7
    ~help:"messages about the evaluation of pointer comparisons"

let widening =
  register_category "widening" ~level:7
    ~help:"print a message at each point where the analysis applies a widening"

let partition =
  register_category "partition" ~level:4
    ~help:"messages about states partitioning"

let split_return =
  register_category "split-return" ~level:4
    ~help:"messages related to option -eva-split-return"

let precision_settings =
  register_category "precision-settings" ~level:3
    ~help:"messages about the automatic configuration of the analysis by \
           option -eva-precision"

let progress =
  register_category "progress" ~level:10
    ~help:"messages about the analysis progress in the C code"

(* ----- Mthread message categories ----------------------------------------- *)

let thread_fixpoint =
  register_category "thread-fixpoint" ~group:Concurrency ~level:3
    ~help:"progress of the analysis fixpoint on threads"

let thread =
  register_category "thread" ~group:Concurrency ~level:4
    ~help:"show each operation on threads interpreted by the analysis"

let mutex =
  register_category "mutex" ~group:Concurrency ~level:8
    ~help:"show each operation on mutexes interpreted by the analysis"

let queue =
  register_category "message-queue" ~group:Concurrency ~level:8
    ~help:"show each operation on message queues interpreted by the analysis"

let data_races =
  register_category "data-races" ~group:Concurrency ~level:3
    ~help:"list of possible data-races detected by the analysis"

(* Created for documentation. *)
let _shared_memory =
  register_category "shared-memory" ~group:Concurrency
    ~help:"all messages about shared memory"

let shared_memory_zone =
  register_category "shared-memory:zone" ~group:Concurrency ~level:3
    ~help:"list of shared memory locations detected by the analysis"

let shared_memory_mutex =
  register_category "shared-memory:mutex" ~group:Concurrency ~level:4
    ~help:"list of mutexes protecting access to each shared memory location"

let shared_memory_mutex_details =
  register_category "shared-memory:mutex-details" ~group:Concurrency ~level:6
    ~help:"more details about mutexes protecting access to shared memory"

let shared_memory_by_iteration =
  register_category "shared-memory:iteration" ~group:Concurrency ~level:7
    ~help:"evolution of shared memory detected at each analysis iteration"

let shared_memory_values =
  register_category "shared-memory:values" ~group:Concurrency ~level:8
    ~help:"values read and written in shared memory during the analysis"

let global_accesses =
  register_category "global-accesses" ~group:Concurrency ~level:11
    ~help:"print all accesses to global variables during the analysis"

(* ----- Other message categories ------------------------------------------- *)

let cvalue_domain =
  register_category "d-cvalue" ~group:Domain ~level:0
    ~help:"print states of the cvalue domain"

let debug_iterator =
  register_category "iterator" ~group:Debug
    ~help:"debug messages about the fixpoint engine on the control-flow graph \
           of functions"

let debug_string_literal =
  register_category "include-string-literals" ~group:Debug ~level:11
    ~help:"when printing a state, \
           also include globals representing string literals"

(* ----- Warning categories ------------------------------------------------- *)

let warn_alarm =
  register_warn_category "alarm"
    ~help:"warnings for each possible undefined behavior detected \
           by the analysis"

let warn_volatile =
  register_warn_category "volatile"
    ~help:"a non-volatile lvalue may point to a volatile memory location"

let warn_locals_escaping =
  register_warn_category "locals-escaping"
    ~help:"a pointer p points to an out of scope local variable \
           (any use of p also generates an alarm)"

let _warn_garbled_mix =
  register_warn_category "garbled-mix"
    ~help:"warnings about very imprecise values inferred for pointers, \
           named garbled mix"

let warn_garbled_mix_write =
  register_warn_category "garbled-mix:write"
    ~help:"the interpretation of an assignment creates a garbled mix"
    ~default:(Feedback 3)

let warn_garbled_mix_assigns =
  register_warn_category "garbled-mix:assigns"
    ~help:"the interpretation of a specification creates a garbled mix"
    ~default:(Feedback 3)

let warn_garbled_mix_summary =
  register_warn_category "garbled-mix:summary"
    ~help:"list the origins of garbled mix at the end of an analysis"
    ~default:(Feedback 3)

let _warn_builtins =
  register_warn_category "builtins"
    ~help:"warnings related to builtins used to interpret some libc functions"

let warn_builtins_missing_spec =
  register_warn_category "builtins:missing-spec"
    ~help:"the ACSL specification on which a builtin soundness relies is missing"

let warn_builtins_override =
  register_warn_category "builtins:override"
    ~help:"a builtin overrides a function definition, which is therefore \
           not analyzed"

let _warn_libc =
  register_warn_category "libc"
    ~help:"warnings related to the interpretation of the standard C library"

let warn_libc_unsupported_spec =
  register_warn_category "libc:unsupported-spec"
    ~help:"the ACSL specification of a libc function is not supported by Eva"

let _warn_loop_unroll =
  register_warn_category "loop-unroll"
    ~help:"messages about loop unrolling"

let warn_loop_unroll_auto =
  register_warn_category "loop-unroll:auto"
    ~help:"a loop is automatically unrolled by -eva-auto-loop-unroll"
    ~default:(Feedback 4)

let warn_loop_unroll_partial =
  register_warn_category "loop-unroll:partial"
    ~help:"a loop has been partially but not completely unrolled"
    ~default:(Feedback 4)

let warn_missing_loop_unroll =
  register_warn_category "loop-unroll:missing"
    ~help:"a loop has no unroll annotation"
    ~default:Inactive

let warn_missing_loop_unroll_for =
  register_warn_category "loop-unroll:missing:for"
    ~help:"a for loop has no unroll annotation"
    ~default:Inactive

let warn_signed_overflow =
  register_warn_category "signed-overflow"
    ~help:"two's complement is used to interpret a signed overflow \
           (when signed overflow alarms are disabled)"

let _warn_assigns =
  register_warn_category "assigns"
    ~help:"warnings related to the interpretation of assigns clauses \
           in ACSL specification"

let warn_invalid_assigns =
  register_warn_category "assigns:invalid-location"
    ~help:"the memory location targeted by an assigns clause is invalid \
           in at least one analysis state"
    ~default:(Feedback 4)

let warn_missing_assigns =
  register_warn_category "assigns:missing"
    ~help:"assigns clauses are missing or incomplete from an ACSL \
           specification on which the analysis soundness relies"
    ~default:Error

let warn_missing_assigns_result =
  register_warn_category "assigns:missing-result"
    ~help:"an assigns \\result clause is missing from an ACSL specification \
           on which the analysis soundness relies"

let warn_experimental =
  register_warn_category "experimental"
    ~help:"an experimental feature of Eva is enabled"

let warn_unknown_size =
  register_warn_category "unknown-size"
    ~help:"the analysis cannot compute the size of a variable, \
           which will thus be very imprecise"

let warn_ensures_false =
  register_warn_category "ensures-false"
    ~help:"a post-condition evaluates to false; \
           there might be an error in the specification"

let warn_watchpoint =
  register_warn_category "watchpoint"
    ~help:"undocumented"
    ~default:(Feedback 2)

let warn_recursion =
  register_warn_category "recursion"
    ~help:"a recursive call is analyzed"
    ~default:(Feedback 3)

let warn_acsl =
  register_warn_category "acsl"
    ~help:"messages about evaluation of ACSL terms and predicates"
    ~default:(Feedback 4)

let warn_acsl_unsupported =
  register_warn_category "acsl:unsupported"
    ~help:"messages about ACSL terms not supported by Eva"
    ~default:(Feedback 4)
