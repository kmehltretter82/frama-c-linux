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

(** {3 Analysis} *)

val is_computed : kernel_function -> bool
val compute : kernel_function -> unit
val compute_all : unit -> unit

val get : Cil_types.kernel_function -> Eva.Assigns.t
val access : Locations.Zone.t -> Eva.Assigns.Memory.t -> Locations.Zone.t

val self : State.t

(** {3 Pretty-printing} *)

val pretty : Format.formatter -> kernel_function -> unit
val display : Format.formatter -> unit

(** {3 Callsite-wise analysis} *)

val compute_all_calldeps : unit -> unit
module Callwise : sig
  val iter : (Cil_types.kinstr -> Eva.Assigns.t -> unit) -> unit
  val find : Cil_types.kinstr -> Eva.Assigns.t
end
