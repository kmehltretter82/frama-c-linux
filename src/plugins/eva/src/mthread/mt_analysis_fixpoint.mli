(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

val mark_shared_nodes_kind : Mt_thread.analysis_state -> unit
val post_thread_analysis : Mt_thread.analysis_state -> unit
val reach_fixpoint : Mt_thread.analysis_state -> unit
