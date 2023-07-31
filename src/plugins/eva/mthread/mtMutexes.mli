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

val mutexes_protecting_zones' :
  (Locations.Zone.t * MtCfgTypes.SetNodeIdAccess.t) list ->
  MtMutexesTypes.MutexesByZone.t
val pretty_with_mutexes :
  Format.formatter -> MtSharedVars.Precise.list_accesses -> unit
type protection = Unprotected | Priority | Protected of MtIds.Id.Set.t
val pretty_protection : Format.formatter -> protection -> unit
val pretty_protection_per_thread :
  Format.formatter -> MtThread.thread * MtThread.thread * protection -> unit
type zone_protection =
  (Locations.Zone.t * (MtThread.thread * MtThread.thread * protection) list)
    list
val pretty_zone_protection :
  Format.formatter ->
  Locations.Zone.t * (MtThread.thread * MtThread.thread * protection) list ->
  unit
val check_protection :
  MtThread.analysis_state ->
  MtSharedVars.Precise.list_accesses -> zone_protection
val pretty_protections :
  Format.formatter ->
  (Locations.Zone.t * (MtThread.thread * MtThread.thread * protection) list)
    list -> unit
val ill_protected :
  MtSharedVars.Precise.list_accesses ->
  zone_protection -> Locations.Zone.t Cil_datatype.Stmt.Hashtbl.t
val need_sync :
  'a Cil_datatype.Stmt.Hashtbl.t -> (Cil_datatype.Stmt.Hashtbl.key * 'a) list
