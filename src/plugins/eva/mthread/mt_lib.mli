(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)


val escape_non_utf8: string -> string


(** Clear the results of the value analysis *)
val clear_value_results: unit -> unit


(** Location of the header file "mthread.h" *)
val mthread_h: unit -> Filepath.t

(** Remove specialchars forbidden in file names *)
val sanitize_filename: ?char:char -> string -> string

(** Threading library stubbed by Mthread. *)
type threads_lib =
  | BuiltinsOnly (** Only Mthread built-ins are available. *)
  | Pthreads (** Pthreads stubs and Mthread built-ins. *)

(** Load the given threads library into Frama-C. *)
val load_threads_library : threads_lib -> unit
