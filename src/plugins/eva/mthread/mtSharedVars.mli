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

val is_model_base : Base.t -> bool
val keep_base : Base.t -> bool
val remove_uninteresting_variables_zone :
  Locations.Zone.t -> Locations.Zone.t
val remove_uninteresting_variables_loc :
  Locations.location -> Locations.location
type mode = VLocal | VGlobal
type collect_params = {
  stmt_multithread : Cil_types.stmt -> bool;
  thread_id : MtIds.id;
  mode : mode;
  iter_requests: Cil_types.stmt -> (Eva.Results.request -> unit) -> unit;
  watch_only : Locations.Zone.t;
}
class do_it :
  collect_params ->
  object
    inherit Visitor.frama_c_inplace
    method accesses : MtSharedVarsTypes.AccessesByZone.map
    method rw_fun : Kernel_function.Hptset.elt -> unit
    method rw_stmt : Cil_types.stmt -> unit
  end


val aux_visitor :
  (Cil_types.stmt -> bool) ->
  MtIds.id -> MtMemory.Types.state_accesser -> Locations.Zone.t -> do_it
val _read_written_by_statement :
  (Cil_types.stmt -> bool) ->
  MtIds.id ->
  MtMemory.Types.state_accesser ->
  ?watch_only:Locations.Zone.t ->
  Cil_types.stmt -> MtSharedVarsTypes.AccessesByZone.map
val read_written_by_function :
  (Cil_types.stmt -> bool) ->
  MtIds.id ->
  MtMemory.Types.state_accesser ->
  ?watch_only:Locations.Zone.t ->
  Kernel_function.Hptset.elt ->
  Cil_types.kinstr -> MtSharedVarsTypes.AccessesByZone.map
val var_thread_created : unit -> Cil_types.varinfo
exception Stmt_is_multithreaded
val stmt_is_multithreaded :
  MtThread.analysis_state ->
  MtMemory.Types.state_accesser -> Cil_types.stmt -> bool
module Aux :
  functor
    (X : sig
       type info
       module Access : Datatype.S with type t = MtTypes.rw * info * MtIds.id
       module Set :
       sig
         include Lattice_type.Lattice_Set with type O.elt = Access.t
         val pretty_aux: Access.t Pretty_utils.formatter -> t Pretty_utils.formatter
       end
       module ZoneMap: Lmap_bitwise.Location_map_bitwise with type v = Set.t

       val thread_data: MtThread.thread -> ZoneMap.map

       val running_concurrently:
         thp:MtThread.thread -> ths:MtThread.thread -> infop:info -> bool
     end)
    ->
    sig
      val fold_location :
        (Locations.location -> X.ZoneMap.LOffset.v -> 'a -> 'a) ->
        X.ZoneMap.map -> 'a -> 'a
      val consider_vars_accesses :
        MtThread.Thread.t ->
        MtThread.Thread.t -> X.Access.t -> X.Access.t -> bool
      val concurrent_accesses_sets :
        (X.Set.O.elt -> X.Set.O.elt -> bool) -> X.Set.t -> X.Set.t -> X.Set.t
      val concurrent_accesses_two_threads :
        MtThread.Thread.t -> MtThread.Thread.t -> X.ZoneMap.map
      val basic_merge_events :
        X.ZoneMap.map -> X.ZoneMap.map -> X.ZoneMap.map
      type list_accesses = (Locations.Zone.t * X.Set.t) list
      val concurrent_accesses_all_threads :
        MtThread.Thread.t list ->
        (list_accesses * list_accesses) * X.ZoneMap.map
      val pretty_concurrent_accesses :
        ?f:X.Access.t Pretty_utils.formatter ->
        unit -> Format.formatter -> list_accesses -> unit
      val all_zones_accessed : list_accesses -> Locations.Zone.t
    end
module Global :
sig
  val fold_location :
    (Locations.location -> MtSharedVarsTypes.AccessesByZone.v -> 'a -> 'a) ->
    MtSharedVarsTypes.AccessesByZone.map -> 'a -> 'a
  val consider_vars_accesses :
    MtThread.Thread.t ->
    MtThread.Thread.t ->
    MtTypes.rw * Cil_types.stmt * MtIds.id ->
    MtTypes.rw * Cil_types.stmt * MtIds.id -> bool
  val concurrent_accesses_sets :
    (MtSharedVarsTypes.StmtIdAccess.t ->
     MtSharedVarsTypes.StmtIdAccess.t -> bool) ->
    MtSharedVarsTypes.SetStmtIdAccess.t ->
    MtSharedVarsTypes.SetStmtIdAccess.t ->
    MtSharedVarsTypes.SetStmtIdAccess.t
  val concurrent_accesses_two_threads :
    MtThread.Thread.t ->
    MtThread.Thread.t -> MtSharedVarsTypes.AccessesByZone.map
  val basic_merge_events :
    MtSharedVarsTypes.AccessesByZone.map ->
    MtSharedVarsTypes.AccessesByZone.map ->
    MtSharedVarsTypes.AccessesByZone.map
  type list_accesses =
    (Locations.Zone.t * MtSharedVarsTypes.SetStmtIdAccess.t) list
  val concurrent_accesses_all_threads :
    MtThread.Thread.t list ->
    (list_accesses * list_accesses) * MtSharedVarsTypes.AccessesByZone.map
  val pretty_concurrent_accesses :
    ?f:(MtTypes.rw * Cil_types.stmt * MtIds.id) Pretty_utils.formatter ->
    unit -> Format.formatter -> list_accesses -> unit
  val all_zones_accessed : list_accesses -> Locations.Zone.t
end
module Precise :
sig
  val fold_location :
    (Locations.location -> MtCfgTypes.AccessesByZoneNode.v -> 'a -> 'a) ->
    MtCfgTypes.AccessesByZoneNode.map -> 'a -> 'a
  val consider_vars_accesses :
    MtThread.Thread.t ->
    MtThread.Thread.t ->
    MtTypes.rw * MtCfgTypes.node * MtIds.id ->
    MtTypes.rw * MtCfgTypes.node * MtIds.id -> bool
  val concurrent_accesses_sets :
    (MtCfgTypes.NodeIdAccess.t -> MtCfgTypes.NodeIdAccess.t -> bool) ->
    MtCfgTypes.SetNodeIdAccess.t ->
    MtCfgTypes.SetNodeIdAccess.t -> MtCfgTypes.SetNodeIdAccess.t
  val concurrent_accesses_two_threads :
    MtThread.Thread.t ->
    MtThread.Thread.t -> MtCfgTypes.AccessesByZoneNode.map
  val basic_merge_events :
    MtCfgTypes.AccessesByZoneNode.map ->
    MtCfgTypes.AccessesByZoneNode.map -> MtCfgTypes.AccessesByZoneNode.map
  type list_accesses =
    (Locations.Zone.t * MtCfgTypes.SetNodeIdAccess.t) list
  val concurrent_accesses_all_threads :
    MtThread.Thread.t list ->
    (list_accesses * list_accesses) * MtCfgTypes.AccessesByZoneNode.map
  val pretty_concurrent_accesses :
    ?f:(MtTypes.rw * MtCfgTypes.node * MtIds.id) Pretty_utils.formatter ->
    unit -> Format.formatter -> list_accesses -> unit
  val all_zones_accessed : list_accesses -> Locations.Zone.t
  val default_offsetmap : Base.validity -> Cvalue.V_Offsetmap.t
  val extract_shared_value :
    MtCfgTypes.CfgNode.t ->
    MtTypes.RW.t ->
    Locations.location ->
    Cvalue.Model.t -> (Base.t * Cvalue.V_Offsetmap.t) list
  val pp_stack : Format.formatter -> MtCfgTypes.CfgNode.t -> unit
  val pp_access :
    MtTypes.RW.t * MtCfgTypes.CfgNode.t * MtIds.Id.t ->
    Base.t -> Cvalue.V_Offsetmap.t -> unit
  val display_shared_vars_value : MtCfgTypes.AccessesByZoneNode.map -> unit
  module WriteSeen :
    Datatype.S_with_collections
    with type t = MtCfgTypes.CfgNode.t * MtIds.Id.t * Locations.Location.t
  val enumerate_written_vars_value :
    MtCfgTypes.AccessesByZoneNode.map ->
    (MtIds.Id.t * Base.t * Cvalue.V_Offsetmap.t) list
  val join_shared_values :
    ('a * Base.t * Cvalue.Model.offsetmap) list -> Cvalue.Model.t
  val remove_non_concur_zones_from_cfg :
    Locations.Zone.t -> MtCfgTypes.CfgNode.t -> unit
  val mark_concur_access_in_cfg :
    ('a * MtCfgTypes.SetNodeIdAccess.t) list -> unit
end
val register_concurrent_var_accesses :
  MtThread.analysis_state ->
  [< `Final of MtMemory.Types.functions_states
  | `Leaf of MtMemory.Types.state ] ->
  unit
