(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

(* -------------------------------------------------------------------------- *)
(* --- Memory Theory                                                      --- *)
(* -------------------------------------------------------------------------- *)

open Lang
open Lang.F

(** {2 Theory} *)

val t_malloc : tau (** allocation tables *)

val t_init : tau (** initialization tables *)

val t_mem : tau -> tau (** t_addr indexed array *)

val f_havoc : lfun
val f_set_init : lfun

val p_is_init_r : lfun
val p_eqmem : lfun
val p_monotonic : lfun

val cinits : term -> pred
val sconst : term -> pred
val framed : term -> pred

(* -------------------------------------------------------------------------- *)

(** {2 Frame Conditions}

    [frames ~addr] are frame conditions for reading a value
    at address [addr] from a chunk of memory.
    The value read at [addr] have length [offset],
    while individual element in memory chunk have type [tau] and
    offset length [sizeof].

    Memory variables use [~basename] or ["mem"] by default.
*)

val frames : addr:term -> offset:term -> sizeof:term ->
  ?basename:string -> tau -> Sigs.frame list

(** {2 Unsupported Union Fields} *)

val unsupported_union : Cil_types.fieldinfo -> unit

(* -------------------------------------------------------------------------- *)
