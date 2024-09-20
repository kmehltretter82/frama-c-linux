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

(** {2 Objectives and limitations}

    The goal of this module is to provide a representation of floating-point
    numbers that statically encode the format of the represented number. As
    for now, the numbers are represented using the OCaml [float] type (which
    are in the [binary64] format) and thus, all operations for the [Long]
    format (or [binary80]) are unsound as they are performed using the
    [binary64] format instead of [binary80] for x86 architectures.

    This is TEMPORARY, and does not break anything in Frama-C as the historical
    way of handling the [Long] format was to use the OCaml [float] type. Future
    improvements of this module WILL INCLUDE a correct way to perform
    computations in the [Long] format.

    The format is nevertheless presents because Frama-C still needs to be able
    to differentiate between the two formats. In particular, the parsing
    process must be able to infer the correct format to store the
    corresponding [fkind], and the logic must know the correct [fkind] to emit
    relevant warnings that partially alleviate the incorrectness resulting
    from Frama-C encoding of [Long] numbers. *)



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



(** {2 Floating point formats}

    Supported floating point formats are declared at the type level to
    enforce a strict manipulation of floating point numbers. *)

type single = Format_Single
type double = Format_Double
type long   = Format_Long

type 'f format =
  | Single : single format (** 32-bits single precision IEEE-754 format. *)
  | Double : double format (** 64-bits double precision IEEE-754 format. *)
  | Long   : long   format (** 80-bits extended precision x86 format. *)

(** Type used to return existantially quantified formats. *)
type resulting_format = Format : 'f format -> resulting_format

(** Returns the format corresponding to the given [fkind]. *)
val format_of_fkind : Cil_types.fkind -> resulting_format

(** Returns the [fkind] corresponding to the given format. *)
val fkind_of_format : 'f format -> Cil_types.fkind

(** Rounds the given float to the [Single] format and return it without types.
    This call is equivalent to [single f |> to_float] and is proposed to
    minimize modifications in the rest of the code base and ensure backward
    compatibility. *)
val round_to_single_precision_float : float -> float



(** {2 Typed floating point numbers} *)

(** Type of statically formatted floating point numbers. The parameter
    specifies the number's format. *)
type 'f t

(** Returns a typed single precision float, performing rounding if needed *)
val single : float -> single t

(** Returns a typed double precision float. *)
val double : float -> double t

(** Returns a typed long precision float. *)
val long : float -> long   t

(** Build a typed float of the given format given an OCaml 64-bits
    floating point number. *)
val represents : float:float -> in_format:'f format -> 'f t

(** Returns the OCaml float represented by a given typed float. *)
val to_float : 'f t -> float

(** Returns the format of a given typed float. *)
val format : 'f t -> 'f format

(** True if the given typed float is finite (not infinite or a NaN). *)
val is_finite : 'f t -> bool

(** True if the given typed float is infinite (but not a NaN). *)
val is_infinite : 'f t -> bool

(** True if the given typed float is a NaN. *)
val is_nan : 'f t -> bool

(** True if the given string's last character corresponds to the given
    format, i.e 'F' for single precision, 'D' for double precision and
    'L' for extended precision. *)
val has_suffix : Cil_types.fkind -> string -> bool

(** Cast a typed floating point number to a new given format.
    Rounding operations are performed when needed. *)
val change_format : _ t -> 'f format -> 'f t



(** {2 Pretty printers}

    The function [pretty_normal] implements a custom printer. The function
    [pretty] relies on kernel's options to decide between using the OCaml
    printer or the [pretty_normal] one. *)

val pretty_normal : use_hex:bool -> Format.formatter -> 'f t -> unit
val pretty : Format.formatter -> 'f t -> unit



(** {2 Parser}

    Parses a typed float from a string. As the represented float may not be
    exact, the parser actually returns three typed floats. The [lower] one
    corresponds to the floating point number computed using the [Downward]
    rounding mode. The [upper] one is based on the [Upward] rounding mode.
    Finally, the [nearest] corresponds to the [Nearest_even] rounding mode.
    As each one of them is typed, the parser must actually returns an
    existantially quantified record, using the [parsed] wrapper type. *)

type 'f parsed_float =
  { lower   : 'f t
  ; nearest : 'f t
  ; upper   : 'f t
  ; format  : 'f format
  }

type parsed_result = Parsed : 'f parsed_float -> parsed_result
val parse : string -> parsed_result



(** {2 Format based constants} *)

(** The significant size of a given format is denoted {m m}.
    The exponent size of a given format is denoted {m e}. *)

(** Returns the largest positive finite floating point number of a given format.
    It is computed as :
    {math \left({2 - 2 ^ {1 - m}}\right) ^ {2 ^ {e - 1} - 1}} *)
val largest_finite_float_of : format:'f format -> 'f t

(** Returns the bounds of the finite range of a given format, i.e the largest
    negative finite floating point number and the largest positive finite
    floating point number of a given format. *)
val finite_range_of : format:'f format -> 'f t * 'f t

(** Returns the smallest positive normalized floating point number of a given
    format. It is computed as :
    {math  {2} ^ {2 - {2} ^ {e - 1}} } *)
val smallest_normal_float_of : format:'f format -> 'f t

(** Returns the smallest positive denormalized floating point number of a
    given format. It is simply computed by setting the least significant bit
    to one, as this bit corresponds to the last bit of the significant. *)
val smallest_denormal_float_of : format:'f format -> 'f t

(** Returns the unit in the last place of a given format, i.e the value of
    the least significant bit of a floating point number with an exponent
    set at zero. It is primally used to overapproximate rounding errors.
    It is computed as {m 2 ^ {-m}}. *)
val unit_in_the_last_place_of : format:'f format -> 'f t



(** {2 Comparisons} *)

val ( =  ) : 'f t -> 'f t -> bool
val ( <> ) : 'f t -> 'f t -> bool
val ( <  ) : 'f t -> 'f t -> bool
val ( <= ) : 'f t -> 'f t -> bool
val ( >  ) : 'f t -> 'f t -> bool
val ( >= ) : 'f t -> 'f t -> bool



(** {2 Correctly rounded arithmetic operations}

    Correctly rounded arithmetic operations. As stated by the IEEE-754 norm,
    computing a correctly rounded operation is exactly equivalent to first
    compute the operation in real arithmetic over the operands and then
    perform a rounding into the floating point format. *)

val neg   : 'f t -> 'f t
val sqrt  : 'f t -> 'f t
val ( + ) : 'f t -> 'f t -> 'f t
val ( - ) : 'f t -> 'f t -> 'f t
val ( * ) : 'f t -> 'f t -> 'f t
val ( / ) : 'f t -> 'f t -> 'f t
val ( mod ) : 'f t -> 'f t -> 'f t



(** {2 Mathematic functions over floating point numbers}

    None of those functions are correctly rounded. They behave exactly as their
    libc equivalents. For each format, the corresponding libc function is
    actually called. For example, computing the exponential of a floating point
    number in single precision uses the libc [expf] function. *)

val exp   : 'f t -> 'f t
val log   : 'f t -> 'f t
val log10 : 'f t -> 'f t
val pow   : 'f t -> 'f t -> 'f t
val fmod  : 'f t -> 'f t -> 'f t
val cos   : 'f t -> 'f t
val sin   : 'f t -> 'f t
val tan   : 'f t -> 'f t
val acos  : 'f t -> 'f t
val asin  : 'f t -> 'f t
val atan  : 'f t -> 'f t
val atan2 : 'f t -> 'f t -> 'f t



(** {2 Floating point numbers as integers} *)

type truncated_to_integer =
  | Integer of Integer.t (** The given float has been succesfully truncated. *)
  | Underflow            (** The given float would underflow if truncated. *)
  | Overflow             (** The given float would overflow if truncated. *)

(** Truncates a given typed floating point number, i.e returns the closest
    integer rounded toward zero, regardless of the current rounding mode.
    The [truncate_to_integer] function converts the given number into an
    64 bits integer it it fits or a token specifying if the conversion is
    impossible due to an underflow or an overflow. *)
val truncate_to_integer : 'f t -> truncated_to_integer

(** Truncate a given typed floating point number, i.e returns the closest
    integer rounded toward zero, regardless of the current rounding mode.
    The [trunc] function is based on the libc equivalent and never fails. *)
val trunc : 'f t -> 'f t

(** Rounds a given typed floating point number to the closest integer. Ties
    are rounded away from zero, regardless of the current rounding mode. *)
val round : 'f t -> 'f t

(** Returns the bits encoding of a given typed floating point number,
    represented as an [Integer]. *)
val bits_encoding : 'f t -> Integer.t
