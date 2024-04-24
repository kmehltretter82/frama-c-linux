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

open Pdg_types

type t = PdgTypes.Pdg.t

val self : State.t

val get : Cil_types.kernel_function -> t
(** Get the PDG of a function. Build it if it doesn't exist yet. *)

(** {3 Pretty printing} *)

val pretty_node : bool -> Format.formatter -> PdgTypes.Node.t -> unit
(** Pretty print information on a node : with [short=true], only the id
      of the node is printed.. *)

val pretty_key : Format.formatter -> PdgIndex.Key.t -> unit
(** Pretty print information on a node key *)

val pretty : ?bw:bool -> Format.formatter -> t -> unit
(** For debugging... Pretty print pdg information.
    Print codependencies rather than dependencies if [bw=true]. *)

val print_dot : t -> string -> unit
(** Pretty print pdg into a dot file. *)
