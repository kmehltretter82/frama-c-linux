(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of [Z] from Zarith. {!Fc_internal_z} only includes to [Zarith.Z]
    module, it is mandatory if we want to call this module [Z] without
    shadowing Zarith's module. This solution is a bit ugly and could be
    replace by [root_module] in kernel dune file, but this does not work for
    now...
    @before Frama-C+dev this module was called [Integer]
*)

(** Previous version of this file did not include [Z], so many more functions
    and operators are available now.
    @since Frama-C+dev
*)
include module type of Fc_internal_z with type t = Fc_internal_z.t
  [@@alert "-fc_internal_z"]

(** {!Z.t} is a Frama-C {!Datatype}, and comes with usual {!compare}, {!equal},
    {!hash} and {!pretty} functions.
    @since Frama-C+dev
*)
include Datatype.S_with_collections with type t := t

(** @since Frama-C+dev *)
val integer: t Type.t

(**************************************************************************)
(** {3 Operators} *)
(**************************************************************************)

(** This module contains all Z operators.
    @since Frama-C+dev
*)
module Operators : sig
  include module type of Compare

  (** Negation {!neg}. *)
  val (~-): t -> t

  (** Addition {!add}. *)
  val (+): t -> t -> t

  (** Subtraction {!sub}. *)
  val (-): t -> t -> t

  (** Multiplication {!mul}. *)
  val ( * ): t -> t -> t

  (** Truncated division {!div}. *)
  val (/): t -> t -> t

  (** Remainder {!rem}. *)
  val (mod): t -> t -> t

  (** Bit-wise logical and {!logand}. *)
  val (land): t -> t -> t

  (** Bit-wise logical inclusive or {!logor}. *)
  val (lor): t -> t -> t

  (** Bit-wise logical exclusive or {!logxor}. *)
  val (lxor): t -> t -> t

  (** Bit-wise logical negation {!lognot}. *)
  val (~!): t -> t

  (** Bit-wise shift to the left {!shift_left}. *)
  val (lsl): t -> int -> t

  (** Bit-wise shift to the right {!shift_right}. *)
  val (asr): t -> int -> t

  (** Conversion from [int] using {!of_int}. *)
  val ( ~$ ) : int -> t

  (** Power {!pow}. *)
  val ( ** ) : t -> int -> t
end

(** Compare operators are not at top level in Zarith.
    @since Frama-C+dev
*)
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

(** Return [true] if the given argument is equal to {!zero}. *)
val is_zero : t -> bool

(** Return [true] if the given argument is equal to {!one}. *)
val is_one : t -> bool

(** Compute [b - a + 1]. *)
val length : t -> t -> t

(** Computes [2^n]. [?limit] can be used to raise an {!Overflow} if the exponent
    is too big. Default value is [1024].
    @raises Overflow if the argument is greater than [?limit]
    @before Frama-C+dev [?limit] argument was not present and all values were
    accepted
*)
val two_power_of_int : ?limit:int -> int -> t

(** Calls {!two_power_of_int} after converting the argument using {!to_int}.
    The default value of [?limit] is set by {!two_power_of_int}.
    @raises Overflow if the argument is greater than limit or if the conversion
    fails
    @before Frama-C+dev [?limit] argument was not present and fixed at [1024]
*)
val two_power : ?limit:int -> t -> t

(** Convert the second argument via {!of_int} then call {!shift_left}.
    This function was previously called [shift_left] but it was renamed to avoid
    shadowing [Z] function.
    @since Frama-C+dev
*)
val shift_left_z : t -> t -> t

(** Convert the second argument via {!of_int} then call {!shift_right}.
    This function was previously called [shift_right] but it was renamed to
    avoid shadowing [Z] function.
    @since Frama-C+dev
*)
val shift_right_z : t -> t -> t

(** @raise Invalid_argument if any argument is negative *)
val shift_right_logical : t -> t -> t

(** [round_up_to_r m r modu] is the smallest number [n] such that
    [n]>=[m] and [n] = [r] modulo [modu].
*)
val round_up_to_r : min:t -> r:t -> modu:t -> t

(** [round_down_to_r m r modu] is the largest number [n] such that
    [n]<=[m] and [n] = [r] modulo [modu].
*)
val round_down_to_r : max:t -> r:t -> modu:t -> t

(** [extract_bits ~start ~stop v] is a shortcut for [extract v pos length]
    where [pos] and [length] are computed using [start] and [stop].
*)
val extract_bits : start:t -> stop:t -> t -> t

val cast: size:t -> signed:bool -> value:t -> t

(**************************************************************************)
(** {3 Printers} *)
(**************************************************************************)

(** Set a maximum above which big ints will be printed in hexadecimal.
    A Negative value turns off this option.
    @since Frama-C+dev
*)
val set_big_ints_hex: int -> unit

(** Prints the integer in hexadecimal format.
    @since 25.0-Manganese
*)
val pretty_hex : t Pretty_utils.formatter

(** Prints the integer in either decimal or hexadecimal depending on
    the value set via {!set_big_ints_hex}.
    @before 25.0-Manganese there was an optional [hexa] argument.
    @before Frama-C+dev Only printed in decimal
*)
val pretty : t Pretty_utils.formatter

(** Print binary format. Digits are output by blocs of 4 bits
    separated by [~sep] with at least [~nbits] total bits. If [nbits] is
    non positive, it will be ignored.

    Positive values are prefixed with ["0b"] and negative values
    are printed as their 2-complement ([lnot]) with prefix ["1b"].
*)
val pp_bin : ?nbits:int -> ?sep:string -> t Pretty_utils.formatter

(** Print hexadecimal format. Digits are output by blocs of 16 bits
    (4 hex digits) separated by [~sep] with at least [~nbits] total bits.
    If [nbits] is non positive, it will be ignored.

    Positive values are preffixed with ["0x"] and negative values
    are printed as their 2-complement ([lnot]) with prefix ["1x"].
*)
val pp_hex : ?nbits:int -> ?sep:string -> t Pretty_utils.formatter
