(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

type 'a t

(* Register a statistic class *)
val register_global_stat : string -> unit t
val register_function_stat : string -> Cil_types.kernel_function t
val register_statement_stat : string -> Cil_types.stmt t

(* Set the stat to the given value *)
val set : 'a t -> 'a -> int -> unit

(* Adds 1 to the stat or set it to 1 if undefined *)
val incr : 'a t -> 'a -> unit

(* Set the stat to the maximum between the current value and the given value *)
val grow : 'a t -> 'a -> int -> unit

(* Reset all statistics to zero *)
val reset_all: unit -> unit

(* Export the computed statistics as CSV *)
val export_as_csv : ?filename:Filepath.Normalized.t -> unit -> unit
