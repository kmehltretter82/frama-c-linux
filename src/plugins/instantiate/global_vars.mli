(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

(** The purpose of this module is to create global variables when it is needed
    by instantiation modules.
*)

(** [get t ghost storage name] searches for an existing variable [name]. If this
    variable does not exists, it is created with the specified type [t], [ghost]
    status and [storage].

    The obtained varinfo does not need to be registered, it will be done by the
    transformation.
*)
val get: typ -> bool -> storage -> string -> varinfo

(** Clears internal tables *)
val clear: unit -> unit

(** Creates a list of global for the variables that have been created *)
val globals: location -> global list
