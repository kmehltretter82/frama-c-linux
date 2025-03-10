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

val mutexes_protecting_zones' :
  (Locations.Zone.t * Mt_cfg_types.SetNodeIdAccess.t) list ->
  Mt_mutexes_types.MutexesByZone.t
val pretty_with_mutexes :
  Format.formatter -> Mt_shared_vars.Precise.list_accesses -> unit
type protection = Unprotected | Priority | Protected of Mutex.Set.t
val pretty_protection : Format.formatter -> protection -> unit
val pretty_protection_per_thread :
  Format.formatter -> Mt_thread.thread * Mt_thread.thread * protection -> unit
type zone_protection =
  (Locations.Zone.t * (Mt_thread.thread * Mt_thread.thread * protection) list)
    list
val pretty_zone_protection :
  Format.formatter ->
  Locations.Zone.t * (Mt_thread.thread * Mt_thread.thread * protection) list ->
  unit
val check_protection :
  Mt_thread.analysis_state ->
  Mt_shared_vars.Precise.list_accesses -> zone_protection
val pretty_protections :
  Format.formatter ->
  (Locations.Zone.t * (Mt_thread.thread * Mt_thread.thread * protection) list)
    list -> unit
val ill_protected :
  Mt_shared_vars.Precise.list_accesses ->
  zone_protection -> Locations.Zone.t Cil_datatype.Stmt.Hashtbl.t
val need_sync :
  'a Cil_datatype.Stmt.Hashtbl.t -> (Cil_datatype.Stmt.Hashtbl.key * 'a) list
