(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

module Outputs :
sig
  val ref_statement : (Cil_types.stmt -> Locations.Zone.t) ref
  val ref_get_external : (Cil_types.kernel_function -> Locations.Zone.t) ref
  val ref_get_internal : (Cil_types.kernel_function -> Locations.Zone.t) ref

  val kinstr : Cil_types.kinstr -> Locations.Zone.t option
  val get_external : Cil_types.kernel_function -> Locations.Zone.t
  val get_internal : Cil_types.kernel_function -> Locations.Zone.t
end

module Inputs :
sig
  val ref_get_external : (Cil_types.kernel_function -> Locations.Zone.t) ref
  val get_external : Cil_types.kernel_function -> Locations.Zone.t
end

(** State_builder.of operational inputs.
    That is:
    - over-approximation of zones whose input values are read by each function,
      State_builder.of sure outputs
    - under-approximation of zones written by each function.
      @see <../inout/Context.html> internal documentation. *)
module Operational_inputs : sig
  (**/**)
  (* Internal use *)
  module Record_Inout_Callbacks: Hook.Iter_hook with type param = Inout_type.t
  (**/**)
end
