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

(** Useful high-level system operations. *)

(* ************************************************************************* *)
(** {2 File Utilities} *)
(* ************************************************************************* *)
 
val pp_to_file : Filepath.Normalized.t -> (Format.formatter -> unit) -> unit
(** [pp_to_file file pp] runs [pp] on a formatter that writes into [file].
    The formatter is always properly flushed and closed on return.
    Exceptions in [pp] are re-raised after closing. *)
[@@deprecated "Use Filepath.with_formatter_exn instead."]
[@@migrate { repl = Filepath.with_formatter_exn } ]

val bincopy : bytes -> in_channel -> out_channel -> unit
(** [copy buffer cin cout] reads [cin] until end-of-file
    and copy it in [cout].
    [buffer] is a temporary string used during the copy.
    Recommended size is [2048].
*)
[@@deprecated]

val copy : Filepath.Normalized.t -> Filepath.Normalized.t -> unit
(** [copy source target] copies source file to target file using [bincopy]. *)
[@@deprecated "Use Filepath.copy instead."]
[@@migrate { repl = Filepath.copy } ]

val read_file : Filepath.Normalized.t -> (in_channel -> 'a) -> 'a
(** Properly close the channel and re-raise exceptions *)
[@@deprecated "Use Filepath.with_open_in_exn instead."]
[@@migrate { repl = Filepath.with_open_in_exn } ]

val read_lines : Filepath.Normalized.t -> (string -> unit) -> unit
(** Iter over all text lines in the file *)
[@@deprecated "Use Filepath.iter_lines instead."]
[@@migrate { repl = Filepath.iter_lines } ]

val write_file : Filepath.Normalized.t -> (out_channel -> 'a) -> 'a
(** Properly close the channel and re-raise exceptions *)
[@@deprecated "Use Filepath.with_open_out_exn instead."]
[@@migrate { repl = Filepath.with_open_out_exn } ]

val print_file : Filepath.Normalized.t -> (Format.formatter -> 'a) -> 'a
(** Properly flush and close the channel and re-raise exceptions *)
[@@deprecated "Use Filepath.with_formatter_exn instead."]
[@@migrate { repl = Filepath.with_formatter_exn } ]

(* ************************************************************************* *)
(** {2 Pretty from files} *)
(* ************************************************************************* *)

val pp_from_file : Format.formatter -> Filepath.Normalized.t -> unit
(** [pp_from_file fmt file] dumps the content of [file] into the [fmt].
    Exceptions in [pp] are re-raised after closing. *)

(* ************************************************************************* *)
(** {2 Timing Utility} *)
(* ************************************************************************* *)

type timer = float ref

val time : ?rmax:timer -> ?radd:timer -> ('a -> 'b) -> 'a -> 'b
(** Compute the elapsed time with [Sys.time].
    The [rmax] timer is maximized and the [radd] timer is cumulated.
    Computed result is returned, or exception is re-raised. *)

(* ************************************************************************* *)
(** {2 System commands} *)
(* ************************************************************************* *)

val full_command :
  string -> string array
  -> stdin:Unix.file_descr
  -> stdout:Unix.file_descr
  -> stderr:Unix.file_descr
  -> Unix.process_status
(** Same arguments as {!Unix.create_process} but returns only when
    execution is complete.
    @raise Sys_error when a system error occurs *)
[@@deprecated]

type process_result =
  | Not_ready of (unit -> unit)
  | Result of Unix.process_status
  (** [Not_ready f] means that the child process is not yet finished and
      may be terminated manually with [f ()]. *)

val full_command_async :
  string -> string array
  -> stdin:Unix.file_descr
  -> stdout:Unix.file_descr
  -> stderr:Unix.file_descr
  -> (unit -> process_result)
(** Same arguments as {!Unix.create_process}.
    @return a function to call to check if the process execution
    is complete.
    You must call this function until it returns a Result
    to prevent Zombie processes.
    @raise Sys_error when a system error occurs *)
[@@deprecated]

val command_async :
  ?stdout:Buffer.t ->
  ?stderr:Buffer.t ->
  string -> string array
  -> (unit -> process_result)
(** Same arguments as {!Unix.create_process}.
    @return a function to call to check if the process execution
    is complete.
    You must call this function until it returns a Result
    to prevent Zombie processes.
    When this function returns a Result, the stdout and stderr of the child
    process will be filled into the arguments buffer.
    @raise Sys_error when a system error occurs *)

val command :
  ?timeout:int ->
  ?stdout:Buffer.t ->
  ?stderr:Buffer.t ->
  string -> string array
  -> Unix.process_status
(** Same arguments as {!Unix.create_process}.
    When this function returns, the stdout and stderr of the child
    process will be filled into the arguments buffer.
    @raise Sys_error when a system error occurs
    @raise Async.Cancel when the computation is interrupted or on timeout
    @before 29.0-Copper Async.Cancel was Db.Cancel
*)
