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

(** Access to other plugins API via {!Dynamic.get}. *)

module Inout: sig
  (** Registers a hook to be called on the inputs/outputs computed by the Inout
      plugin for each function call. *)
  val register_call_hook: (Inout_type.t -> unit) -> unit

  (** Returns the memory zone read by the given function (including local
      and formal variables). Returns Top if the inout plugin is missing. *)
  val kf_inputs: Kernel_function.t -> Locations.Zone.t

  (** Returns the memory zone modified by the given function (including local
      and formal variables). Returns Top if the inout plugin is missing. *)
  val kf_outputs: Kernel_function.t -> Locations.Zone.t

  (** Returns the memory zone modified by the given statement.
      Returns Top if the inout plugin is missing. *)
  val stmt_outputs: Cil_types.stmt -> Locations.Zone.t
end

module Callgraph: sig
  (** Iterates over all functions in the callgraph in reverse order, i.e. from
      callees to callers. If callgraph is missing or if the number of callsites
      is too big, the order is unspecified. *)
  val iter_in_rev_order: (Kernel_function.t -> unit) -> unit
end

module Scope: sig
  (** Removes redundant assertions. Warns if the scope plugin is missing. *)
  val rm_asserts: unit -> unit
end

module RteGen: sig
  (** Marks all RTE as generated. Does nothing if the rte plugin is missing. *)
  val mark_generated_rte: unit -> unit
end
