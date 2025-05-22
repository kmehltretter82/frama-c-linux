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

(** This module provides a layer above the {!Filesystem} module to handle
    automatic removal of temporary files when the program exits, except if exit
    is caused by a signal and except if [keep] is given and set to true. If
    [keep] is omitted, the files are only kept if the debug key
    {!Kernel.dkey_pp_keep_temp_files} is set. If the file is kept, a message
    with the path of the preserved file or directory is emitted. When the
    temporary file or directory cannot be created, these functions abort. *)

(** [cleanup_at_exit file] indicates that [file] must be removed when the
    program exits (except if exit is caused by a signal).
    If [file] does not exist, nothing happens.
    @since 31.0-Gallium
    @before 31.0-Gallium was in Extlib and used a string instead of
    [Filepath.t] *)
val cleanup_at_exit: Filepath.t -> unit

(** Similar to [Filename.temp_file] except that the temporary file will be
    deleted at the end of the execution (see above).
    @raise Temp_file_error if the temp file cannot be created.
    @before 31.0-Gallium was in Extlib and returned a string instead of
    [Filepath.t], raised Temp_file_error, [keep] was named [debug] and [prefix]
    and [suffix] arguments were not named. *)
val file: ?keep:bool -> prefix:string -> suffix:string -> unit -> Filepath.t

(** Similar to [Filename.temp_dir] except that the temporary directory will be
    deleted at the end of the execution (see above).
    @before 28.0-Nickel returned a string instead of [Filepath.t]
    @before 31.0-Gallium was in Extlib, raised Temp_file_error and [keep] was named [debug] and [prefix]
    and [suffix] arguments were not named. *)
val dir: ?keep:bool -> prefix:string -> suffix:string -> unit -> Filepath.t
