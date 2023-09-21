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

(** The datastructures of this module can be used to track the origin
    of a major imprecision in the values of an abstract domain. *)

(** This module is generic, although currently used only by the plugin Value.
    Within Value, values that have an imprecision origin are "garbled mix",
    ie. a numeric value that contains bits extracted from at least one
    pointer, and that are not the result of a translation *)

include Datatype.S

type kind =
  | Misalign_read
  | Leaf
  | Merge
  | Arith

val current: kind -> t
(** This is automatically extracted from [Cil.CurrentLoc] *)

val well: t
val unknown: t
val is_unknown: t -> bool

val pretty_as_reason: Format.formatter -> t -> unit
(** Pretty-print [because of <origin>] if the origin is not {!Unknown}, or
    nothing otherwise *)

val join: t -> t -> t
val is_included: t -> t -> bool

val is_precise: t -> bool

(** Records the write of an imprecise value of the given bases,
    with the given origin. *)
val register_write: Base.SetLattice.t -> t -> unit

(** Records the read of an imprecise value of the given bases,
    with the given origin. *)
val register_read: Base.SetLattice.t -> t -> unit

(** Pretty-print a summary of the origins of imprecise values recorded
    by [register_write] and [register_read] above. *)
val pretty_history: Format.formatter -> unit

(** Clears the history of origins saved by [register_write] and
    [register_read] above. *)
val clear: unit -> unit

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
