(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of [Z] from Zarith. {!Fc_z} only includes to [Zarith.Z] module, it
    is mandatory if we want to call this module [Z] without shadowing Zarith's
    module. This solution is a bit ugly and could be replace by [root_module]
    in kernel dune file, but this does not work for now...
    @since Frama-C+dev *)

include module type of Fc_z with type t = Fc_z.t [@@alert "-fc_z"]

(**************************************************************************)
(** {3 Operators} *)
(**************************************************************************)

(** This module contains all Z operators.
    @since Frama-C+dev
*)
module Operators : sig
  include module type of Compare

  val (~-): t -> t
  (** Negation {!neg}. *)

  val (+): t -> t -> t
  (** Addition {!add}. *)

  val (-): t -> t -> t
  (** Subtraction {!sub}. *)

  val ( * ): t -> t -> t
  (** Multiplication {!mul}. *)

  val (/): t -> t -> t
  (** Truncated division {!div}. *)

  val (mod): t -> t -> t
  (** Remainder {!rem}. *)

  val (land): t -> t -> t
  (** Bit-wise logical and {!logand}. *)

  val (lor): t -> t -> t
  (** Bit-wise logical inclusive or {!logor}. *)

  val (lxor): t -> t -> t
  (** Bit-wise logical exclusive or {!logxor}. *)

  val (~!): t -> t
  (** Bit-wise logical negation {!lognot}. *)

  val (lsl): t -> int -> t
  (** Bit-wise shift to the left {!shift_left}. *)

  val (asr): t -> int -> t
  (** Bit-wise shift to the right {!shift_right}. *)

  val ( ~$ ) : int -> t
  (** Conversion from [int] using {!of_int}. *)

  val ( ** ) : t -> int -> t
  (** Power {!pow}. *)
end

(** Compare operators are not at top level in Zarith. *)
include module type of Compare

(**************************************************************************)
(** {3 Conversions} *)
(**************************************************************************)

(** Returns [Some i] if the number can be converted to an [int], or [None]
    otherwise.
    @since 24.0-Chromium
*)
val to_int_opt : t -> int option

(** Returns [Some i] if the number can be converted to an [int32], or [None]
    otherwise.
    @since 24.0-Chromium
*)
val to_int32_opt : t -> int32 option

(** Returns [Some i] if the number can be converted to an [int64], or [None]
    otherwise.
    @since 24.0-Chromium
*)
val to_int64_opt : t -> int64 option

(**************************************************************************)
(** {3 Basic functions, most of them from Z} *)
(**************************************************************************)

val is_zero : t -> bool
val is_one : t -> bool

val is_even : t -> bool

val length : t -> t -> t (** b - a + 1 *)

val two_power : t -> t
(** Computes [2^n].
    @raise Overflow for exponents greater than 1024 *)

val two_power_of_int : int -> t
(** Computes [2^n]. *)

val shift_left_z : t -> t -> t
(** Convert the second argument via {!of_int} then call {!shift_left}.
    @since Frama-C+dev
*)

val shift_right_z : t -> t -> t
(** Convert the second argument via {!of_int} then call {!shift_right}.
    @since Frama-C+dev
*)

val shift_right_logical : t -> t -> t
(** @raise Invalid_argument if any argument is negative *)

val round_up_to_r : min:t -> r:t -> modu:t -> t
(** [round_up_to_r m r modu] is the smallest number [n] such that
    [n]>=[m] and [n] = [r] modulo [modu]. *)

val round_down_to_r : max:t -> r:t -> modu:t -> t
(** [round_down_to_r m r modu] is the largest number [n] such that
    [n]<=[m] and [n] = [r] modulo [modu]. *)

val extract_bits : start:t -> stop:t -> t -> t
(** [extract_bits ~start ~stop v] is a shortcut for [extract v pos length]
    where [pos] and [length] are computed using [start] and [stop].
*)

val cast: size:t -> signed:bool -> value:t -> t

(**************************************************************************)
(** {3 Printers} *)
(**************************************************************************)

(** Prints the integer in decimal format. See also {!pretty_hex}.

    @before 25.0-Manganese there was an optional [hexa] argument. *)
val pretty : t Pretty_utils.formatter

(** Prints the integer in hexadecimal format (replaces [hexa] optional
    argument of {!pretty} from older versions).

    @since 25.0-Manganese *)
val pretty_hex : t Pretty_utils.formatter

val pp_bin : ?nbits:int -> ?sep:string -> t Pretty_utils.formatter
(** Print binary format. Digits are output by blocs of 4 bits
    separated by [~sep] with at least [~nbits] total bits. If [nbits] is
    non positive, it will be ignored.

    Positive values are prefixed with ["0b"] and negative values
    are printed as their 2-complement ([lnot]) with prefix ["1b"]. *)

val pp_hex : ?nbits:int -> ?sep:string -> t Pretty_utils.formatter
(** Print hexadecimal format. Digits are output by blocs of 16 bits
    (4 hex digits) separated by [~sep] with at least [~nbits] total bits.
    If [nbits] is non positive, it will be ignored.

    Positive values are preffixed with ["0x"] and negative values
    are printed as their 2-complement ([lnot]) with prefix ["1x"]. *)
