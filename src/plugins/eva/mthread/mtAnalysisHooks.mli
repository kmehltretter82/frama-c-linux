(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

open MtMemory.Types
open MtThread

(** A correct value for the main thread *)
val main_thread: Cil_types.kernel_function -> state -> thread


(** Exception to be returned when a hook did not process fully correctly, to be
    caught the level of hook registration. The [int] is the erro code *)
exception Hook_failure of int

(** List of builtins that are to be registered by Mthread. We use
    a simplified interface compared to what the value analysis can
    require. The callbacks can raise [Hook_failure] if they did not
    proceed correctly *)
val mthread_builtins:
  (string *
   (analysis_state ->
    state ->
    (Eva.Eva_ast.exp * value) list ->
    state * value option)
  ) list


(** Function to register with [Eva.Cvalue_callbacks.register_call_hooks]
    (called before each function call processed in the analysis) *)
val catch_functions_calls: analysis_state -> Eva.Cvalue_callbacks.call_hook

(** Function to register with [Eva.Cvalue_callbacks.register_call_results_hook]
    (called after each function call processed by the analysis. *)
val catch_functions_record:
  analysis_state -> Eva.Cvalue_callbacks.call_results_hook
