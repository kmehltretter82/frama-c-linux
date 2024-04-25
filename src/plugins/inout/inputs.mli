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

val self: State.t

val compute: Cil_types.kernel_function -> unit
val get_external: Cil_types.kernel_function -> Locations.Zone.t
val get_internal: Cil_types.kernel_function -> Locations.Zone.t
val statement: Cil_types.stmt -> Locations.Zone.t
val expr: Cil_types.stmt -> Cil_types.exp -> Locations.Zone.t

val pretty_external: Format.formatter -> Cil_types.kernel_function -> unit
val pretty_with_formals: Format.formatter -> Cil_types.kernel_function -> unit
