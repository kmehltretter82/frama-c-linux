(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

val self: State.t

val compute: Cil_types.kernel_function -> unit
val get_internal: Cil_types.kernel_function -> Locations.Zone.t
val get_external: Cil_types.kernel_function -> Locations.Zone.t
val statement: Cil_types.stmt -> Locations.Zone.t

val pretty_external: Format.formatter -> Cil_types.kernel_function -> unit
val pretty_internal: Format.formatter -> Cil_types.kernel_function -> unit
