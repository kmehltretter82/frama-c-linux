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

(** Returns the memory zone needed to evaluate the given expression at the
    given statement. *)
val expr_inputs: stmt -> exp -> Locations.Zone.t

(** Returns the memory zone read by the given statement. *)
val stmt_inputs: stmt -> Locations.Zone.t

(** Returns the memory zone modified by the given statement. *)
val stmt_outputs: stmt -> Locations.Zone.t

(** Returns the memory zone read by the given function, including its
    local and formal variables. *)
val kf_inputs: kernel_function -> Locations.Zone.t

(** Returns the memory zone read by the given function, without its
    local and formal variables. *)
val kf_external_inputs: kernel_function -> Locations.Zone.t

(** Returns the memory zone modified by the given function, including its
    local and formal variables. *)
val kf_outputs: kernel_function -> Locations.Zone.t

(** Returns the memory zone modified by the given function, without its
    local and formal variables. *)
val kf_external_outputs: kernel_function -> Locations.Zone.t

(** Returns the inputs/outputs computed for the given function.
    If [stmt] is specified and is a possible call to the given function,
    returns the inputs/outputs for this call specifically. *)
val get_precise_inout: ?stmt:stmt -> kernel_function -> Inout_type.t

val self: State.t
