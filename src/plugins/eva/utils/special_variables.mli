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

(** Special variables created by Eva for its analysis. *)

open Cil_types

(** Creates and registers a new global variable of the given type. The created
    variable is not a source variable. The freshness of the name must be ensured
    by the user.
    A description [descr] of the variable can be optionally given. If [libc] is
    true, the created variable has the "fc_stdlib_generated" attribute.
    Returns the created varinfos and the associated base. The base validity can
    be provided; otherwise, it is computed from the given type.  *)
val create_global:
  string -> ?descr:string -> ?libc:bool -> ?validity:Base.validity
  -> typ -> varinfo * Base.t

(** Creates and registers a new allocated variable of the given type.
    The freshness of the name must be ensured by the user.
    Returns the created varinfos and the associated base. The base validity can
    be provided; otherwise, it is computed from the given type.  *)
val create_allocated:
  string -> typ -> weak:bool
  -> min_alloc:Integer.t -> max_alloc:Integer.t -> kind:Base.deallocation
  -> varinfo * Base.t
