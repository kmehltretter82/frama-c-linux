(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

val mark_new_messages_received : MtThread.analysis_state -> unit
val record_end_of_thread_analysis : MtThread.analysis_state -> unit
val compute_thread : MtThread.analysis_state -> MtThread.thread -> unit
val recompute_shared_vars_changed :
  MtThread.analysis_state -> Locations.Zone.t -> unit
val recompute_shared_vars_values_changed :
  MtThread.analysis_state ->
  MtThread.thread -> Cvalue.Model.t -> Cvalue.Model.lmap -> unit
val compute_shared_vars :
  MtThread.analysis_state ->
  (Locations.Zone.t * MtCfgTypes.SetNodeIdAccess.t) list *
  (MtIds.Id.t * Base.t * Cvalue.V_Offsetmap.t) list
val store_written_value :
  MtThread.analysis_state ->
  (MtIds.Id.t * Base.t * Cvalue.Model.offsetmap) list -> unit
val one_iteration : MtThread.analysis_state -> bool
val mark_shared_nodes_kind : MtThread.analysis_state -> unit
val reach_fixpoint : MtThread.analysis_state -> unit
