(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

type script =
  | NoScript
  | Script of Filepath.Normalized.t
  | Deprecated of Filepath.Normalized.t

type mode =
  | Batch
  | Update
  | Dry
  | Init

val get_mode : unit -> mode
val set_mode : mode -> unit

val scratch_mode : unit -> bool
val saving_mode : unit -> bool

val pp_file : Format.formatter -> Filepath.Normalized.t -> unit
val pp_script_for : Format.formatter -> Wpo.t -> unit

val get : Wpo.t -> script
val exists : Wpo.t -> bool
val save : stdout:bool -> Wpo.t -> Json.t -> unit
val load : Wpo.t -> Json.t
val remove : Wpo.t -> unit

val filename : force:bool -> Wpo.t -> Filepath.Normalized.t

val mark : Wpo.t -> unit
val reset_marks : unit -> unit
val remove_unmarked_files : dry:bool -> unit

(**************************************************************************)
