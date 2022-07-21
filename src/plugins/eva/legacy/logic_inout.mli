(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

(** Functions used by the Inout and From plugins to interpret predicate
    and assigns clauses. This API may change according to these plugins
    development. *)

(** [predicate_deps ~pre ~here p] computes the logic dependencies needed
    to evaluate the predicate [p] in cvalue state [here], in a function
    whose pre-state is [pre].
    Returns None on either an evaluation error or on unsupported construct. *)
val predicate_deps:
  pre:Cvalue.Model.t -> here:Cvalue.Model.t ->
  Cil_types.predicate -> Locations.Zone.t option

(** Returns the list of behaviors of the given function that are active for
    the given initial state. *)
val valid_behaviors:
  Cil_types.kernel_function -> Cvalue.Model.t -> Cil_types.behavior list

(** Evaluation of the memory zone read by the \from part of an assigns clause,
    in the given cvalue state.  *)
val assigns_inputs_to_zone:
  Cvalue.Model.t -> Cil_types.assigns -> Locations.Zone.t

(** Evaluation of the memory zone written by an assigns clauses, in the given
    cvalue state. *)
val assigns_outputs_to_zone:
  result: Cil_types.varinfo option ->
  Cvalue.Model.t -> Cil_types.assigns -> Locations.Zone.t

(** Evaluate the assigns clauses of the given function in its given pre-state,
    and compare them with the given froms (computed by the from plugin).
    Emits warnings if needed, and sets statuses to the assigns clauses. *)
val verify_assigns:
  Cil_types.kernel_function -> pre:Cvalue.Model.t -> Function_Froms.froms -> unit

[@@@ api_end]
