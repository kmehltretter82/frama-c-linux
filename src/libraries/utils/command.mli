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
(** {2 Pretty from files} *)
(* ************************************************************************* *)

val pp_from_file : Format.formatter -> Filepath.t -> unit
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

type process_result =
  | Not_ready of (unit -> unit)
  | Result of Unix.process_status
  (** [Not_ready f] means that the child process is not yet finished and
      may be terminated manually with [f ()]. *)

val async :
  ?stdout:Buffer.t ->
  ?stderr:Buffer.t ->
  string -> string list
  -> (unit -> process_result)
(** Same arguments as {!Unix.create_process}.
    @return a function to call to check if the process execution
    is complete.
    You must call this function until it returns a Result
    to prevent Zombie processes.
    When this function returns a Result, the stdout and stderr of the child
    process will be filled into the arguments buffer.
    @raise Sys_error when a system error occurs
    @before 31.0-Gallium this function was named [command_async] *)

val spawn :
  ?timeout:int ->
  ?stdout:Buffer.t ->
  ?stderr:Buffer.t ->
  string -> string list
  -> Unix.process_status
(** Same arguments as {!Unix.create_process}.
    When this function returns, the stdout and stderr of the child
    process will be filled into the arguments buffer.
    @raise Sys_error when a system error occurs
    @raise Async.Cancel when the computation is interrupted or on timeout
    @before 29.0-Copper Async.Cancel was Db.Cancel
    @before 31.0-Gallium this function was named [command]
*)
