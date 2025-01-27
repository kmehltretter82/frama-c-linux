(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(** {2 Rounding modes} *)

type rounding =
  | Nearest_even (** Rounding to nearest, tie to even. *)
  | Upward       (** Rounding toward +∞. *)
  | Downward     (** Rounding toward -∞. *)
  | Toward_zero  (** Rounding toward zero. *)

(** Set the current rounding mode. *)
val set_rounding_mode : rounding -> unit

(** Get the current rounding mode. *)
val get_rounding_mode : unit -> rounding

(** Rounds the given float to a single precision float. *)
val round_to_single_precision_float : float -> float


(** {2 Floating-point operations} *)

type truncated_to_integer =
  | Integer of Integer.t (** The given float has been succesfully truncated. *)
  | Underflow            (** The given float would underflow if truncated. *)
  | Overflow             (** The given float would overflow if truncated. *)

(** Truncates a given floating point number, i.e returns the closest
    integer rounded toward zero, regardless of the current rounding mode.
    The [truncate_to_integer] function converts the given number into an
    64 bits integer it it fits or a token specifying if the conversion is
    impossible due to an underflow or an overflow. *)
val truncate_to_integer : float -> truncated_to_integer


(** True if the given float is finite (not infinite or a NaN). *)
val is_finite : float -> bool

(** True if the given float is infinite (but not a NaN). *)
val is_infinite : float -> bool

(** True if the given float is a NaN. *)
val is_nan : float -> bool

(** {2 Pretty printers}

    The function [pretty_normal] implements a custom printer. The function
    [pretty] relies on kernel's options to decide between using the OCaml
    printer or the [pretty_normal] one. *)

val pretty_normal : use_hex:bool -> Format.formatter -> float -> unit
val pretty : Format.formatter -> float -> unit

(** True if the given string's last character corresponds to the given
    format, i.e 'F' for single precision, 'D' for double precision and
    'L' for extended precision. *)
val has_suffix : Cil_types.fkind -> string -> bool
