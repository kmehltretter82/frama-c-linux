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

(** This module is used to track the origin of very imprecise values
    (namely "garbled mix", created on imprecise or unsupported operations on
    addresses) propagated by an Eva analysis. *)

include Datatype.S

type kind =
  | Misalign_read (* Misaligned read of addresses *)
  | Misalign_write (* Misaligned write of addresses *)
  | Leaf  (* Interpretation of assigns clause *)
  | Merge (* Imprecise merge of addresses *)
  | Arith (* Arithmetic operation on addresses *)

(** Creates an origin of the given kind, associated with the current source
    location extracted from [Current_loc]. *)
val current: kind -> t

(** Origin for garbled mix created in the initial state of the analysis
    (not associated to a source location). *)
val well: t

(** Unknown origin. *)
val unknown: t
val is_unknown: t -> bool

(** Pretty-print [because of <origin>] if the origin is not {!Unknown}, or
    nothing otherwise. *)
val pretty_as_reason: Format.formatter -> t -> unit

(** Short description of an origin. *)
val descr: t -> string

val join: t -> t -> t

(** Records the creation of an imprecise value of the given bases. *)
val register: Base.SetLattice.t -> t -> unit

(** Records the write of an imprecise value of the given bases,
    with the given origin.
    Returns [true] if the given origin has never been written before,
    and if it is related to the current location — in which case a warning
    should probably be emitted. *)
val register_write: Base.SetLattice.t -> t -> bool

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
