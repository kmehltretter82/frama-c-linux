(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)


(** Threading library stubbed by Mthread. *)
type threads_lib =
  | BuiltinsOnly (** Only Mthread built-ins are available. *)
  | Pthreads (** Pthreads stubs and Mthread built-ins. *)

(** Load the given threads library into Frama-C. *)
val load_threads_library : threads_lib -> unit
