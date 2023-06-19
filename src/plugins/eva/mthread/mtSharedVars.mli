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

module type Computer =
sig
  module Access : Datatype.S
  module Set: Lattice_type.Lattice_Set with type O.elt = Access.t
  module ZoneMap: Lmap_bitwise.Location_map_bitwise with type v = Set.t

  type list_accesses = (Locations.Zone.t * Set.t) list

  val pretty_concurrent_accesses :
    ?f:Access.t Pretty_utils.formatter ->
    unit -> Format.formatter -> list_accesses -> unit

  val all_zones_accessed : list_accesses -> Locations.Zone.t

  val concurrent_accesses_all_threads :
    MtThread.Thread.t list ->
    (list_accesses * list_accesses) * ZoneMap.map
end

module Global : Computer
  with module Access = MtSharedVarsTypes.StmtIdAccess
   and module Set = MtSharedVarsTypes.SetStmtIdAccess

module Precise :
sig
  include Computer
    with module Access = MtCfgTypes.NodeIdAccess
     and module Set = MtCfgTypes.SetNodeIdAccess

  val display_shared_vars_value : ZoneMap.map -> unit 
  val enumerate_written_vars_value :
    ZoneMap.map ->
    (MtIds.Id.t * Base.t * Cvalue.V_Offsetmap.t) list
  val join_shared_values :
    ('a * Base.t * Cvalue.Model.offsetmap) list -> Cvalue.Model.t
  val remove_non_concur_zones_from_cfg :
    Locations.Zone.t -> MtCfgTypes.CfgNode.t -> unit
  val mark_concur_access_in_cfg :
  ('a * Set.t) list -> unit
end


val read_written_by_function :
  (Cil_types.stmt -> bool) ->
  MtIds.id ->
  MtMemory.Types.state_accesser ->
  ?watch_only:Locations.Zone.t ->
  Kernel_function.Hptset.elt ->
  Cil_types.kinstr -> MtSharedVarsTypes.AccessesByZone.map

val register_concurrent_var_accesses :
  MtThread.analysis_state ->
  [< `Final of MtMemory.Types.functions_states
  | `Leaf of MtMemory.Types.state ] ->
  unit

val stmt_is_multithreaded :
  MtThread.analysis_state ->
  MtMemory.Types.state_accesser -> Cil_types.stmt -> bool

val var_thread_created : unit -> Cil_types.varinfo