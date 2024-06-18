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

open Cil_types

exception Top
(** Used for postdominators-related functions, when the
    postdominators of a statement cannot be computed. It means that
    there is no path from this statement to the function return. *)

val compute: kernel_function -> unit

val stmt_postdominators:
  kernel_function -> stmt -> Cil_datatype.Stmt.Hptset.t
(** @raise Top (see above) *)

val is_postdominator:
  kernel_function -> opening:stmt -> closing:stmt -> bool

val display: unit -> unit

val print_dot : string -> kernel_function -> unit
(** Print a representation of the postdominators in a dot file
    whose name is [basename.function_name.dot]. *)
