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

[@@@ api_start]
(** This module keeps track of statistics collected by Eva during an
    analysis. *)

(** Type of statistics. Type parameter ['ty] is either bound to [int] or
    [float] for integer and float statistics respectively and ['k] show whether
    a statistic is tied:
    - to [kernel_function],
    - to Cil [stmt],
    - to the whole program, with [unit].  *)
type ('k, 'ty) t

(** {2 Registered statistics } *)

val iterations : (Cil_types.stmt, int) t
val memexec_hits : (Cil_types.kernel_function, int) t
val memexec_misses : (Cil_types.kernel_function, int) t
val max_widenings : (Cil_types.stmt, int) t
val max_unrolling : (Cil_types.stmt, int) t
val partitioning_index_hits : (unit, int) t
val partitioning_index_misses : (unit, int) t


(** {2 Statistics registration } *)

type _ typ =
  | Int : int typ
  | Float : float typ

(** Registers a statistic tied to the whole program. *)
val register_global_stat : string -> 'ty typ -> (unit,'ty) t

(** Registers a statistic tied to functions. *)
val register_function_stat :
    string -> 'ty typ ->(Cil_types.kernel_function, 'ty) t

(** Registers a statistic tied to statements. *)
val register_statement_stat : string -> 'ty typ -> (Cil_types.stmt, 'ty) t


(** {2 Statistics retrieval } *)

(** Get the current stat value for a given element (statement, function or unit
    according to the statistic type). **)
val get : ('k, 'ty) t -> 'k -> 'ty


(** {2 Statistics update } *)

(** Set the stat to the given value. *)
val set : ('k, 'ty) t -> 'k -> 'ty -> unit

(** Adds 1 to the stat or set it to 1 if the stat is currently undefined. *)
val incr : ('k, int) t -> 'k -> unit

(** Add a custom amount to the stat or set it to this amount the stat is
    currently undefined. *)
val add : ('k, 'ty) t -> 'k -> 'ty -> unit

(** Set the stat to the maximum between the current value and the given
    value. *)
val grow : ('k, 'ty) t -> 'k -> 'ty -> unit
[@@@ api_end]

(** Reset all statistics to zero. *)
val reset_all: unit -> unit


(** {2 Export } *)

(** Export the computed statistics as CSV. *)
val export_as_csv : ?filename:Filepath.t -> unit -> unit
