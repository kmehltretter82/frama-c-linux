(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Registers a hook called at the end of the Mthread analysis. *)
val register_analysis_hook: (Mt_thread.analysis_state -> unit) -> unit

(** Apply registered hooks on the current analysis. *)
val apply_analysis_hooks : unit -> unit
