(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

type mode = NoCache | Update | Replay | Rebuild | Offline | Cleanup

val get_dir : unit -> string

val set_mode : mode -> unit
val get_mode : unit -> mode
val get_hits : unit -> int
val get_miss : unit -> int
val get_removed : unit -> int

val is_updating : unit -> bool

val cleanup_cache : unit -> unit

type runner =
  timeout:int option -> steplimit:int option ->
  Why3.Driver.driver -> Why3Provers.t -> Why3.Task.task ->
  VCS.result Task.task

val get_result: Wpo.t -> runner -> runner
