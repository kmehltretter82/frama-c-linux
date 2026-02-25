(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

val register_hooks: Mt_thread.analysis_state -> unit
val unregister_hooks: unit -> unit
val checks: unit -> unit
val make_analysis_state: unit -> Mt_thread.analysis_state
val post_analysis: Mt_thread.analysis_state -> unit
