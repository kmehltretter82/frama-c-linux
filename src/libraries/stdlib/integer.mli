(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of [Big_int] compatible with [Zarith].
    @since Nitrogen-20111001 *)

type t = Z.t

type 'a formatter = Format.formatter -> 'a -> unit

(**************************************************************************)
(** {3 Conversions} *)
(**************************************************************************)

val of_int : int -> t
val of_int32 : Int32.t -> t
val of_int64 : Int64.t -> t

(**
   @raise Z.Overflow if too big
   @since 24.0-Chromium
*)
val to_int_exn : t -> int

(**
   @raise Z.Overflow if too big
   @since 24.0-Chromium
*)
val to_int32_exn : t -> int32

(**
   @raise Z.Overflow if too big
   @since 24.0-Chromium
*)
val to_int64_exn : t -> int64

(**
   Returns [Some i] if the number can be converted to an [int],
   or [None] otherwise.
   @since 24.0-Chromium
*)
val to_int_opt : t -> int option

(**
   Returns [Some i] if the number can be converted to an [int32],
   or [None] otherwise.
   @since 24.0-Chromium
*)
val to_int32_opt : t -> int32 option

(**
   Returns [Some i] if the number can be converted to an [int64],
   or [None] otherwise.
   @since 24.0-Chromium
*)
val to_int64_opt : t -> int64 option

val to_float : t -> float
val of_float : float -> t

val to_string : t -> string
val of_string : string -> t
(** @raise Invalid_argument when the string cannot be parsed. *)

(**************************************************************************)
(** {3 Numbers} *)
(**************************************************************************)

val minus_one : t
val zero : t
val one : t

(**************************************************************************)
(** {3 Basic functions, most of them from Z} *)
(**************************************************************************)

val equal : t -> t -> bool
val compare : t -> t -> int

val leq : t -> t -> bool
val geq : t -> t -> bool
val lt  : t -> t -> bool
val gt  : t -> t -> bool

val add : t -> t -> t
val sub : t -> t -> t
val mul : t -> t -> t

val abs : t -> t
val neg : t -> t
val succ : t -> t
val pred : t -> t

val is_zero : t -> bool
val is_one : t -> bool

val is_even : t -> bool

val length : t -> t -> t (** b - a + 1 *)

val two_power : t -> t
(** Computes [2^n]
    @raise Z.Overflow for exponents greater than 1024 *)

val two_power_of_int : int -> t
(** Computes [2^n] *)

val power_int_positive_int_opt : int -> int -> t option
(** Exponentiation *)

val shift_left : t -> t -> t
(** @raise Invalid_argument if second argument (count) is negative *)

val shift_right : t -> t -> t
(** @raise Invalid_argument if second argument (count) is negative *)

val shift_right_logical : t -> t -> t
(** @raise Invalid_argument if any argument is negative *)

val logand : t -> t -> t
val logor : t -> t -> t
val logxor : t -> t -> t
val lognot : t -> t

val min : t -> t -> t
val max : t -> t -> t

val ediv : t -> t -> t
(** Euclidean division (that returns a positive rem).
    Implemented by [Z.ediv]

    Equivalent to C division if both operands are positive.
    Equivalent to a floored division if b > 0 (rounds downwards),
    otherwise rounds upwards.
    Note: it is possible that e_div (-a) b <> e_div a (-b).
*)

val erem : t -> t -> t
(** Remainder of the Euclidean division (always positive).
    Implemented by [Z.erem] *)

val ediv_rem: t -> t -> (t * t)
(** [ediv_rem a b] returns [(ediv a b, erem a b)].
    Implemented by [Z.ediv_rem] *)

val div : t -> t -> t
(** Truncated division towards 0 (like in C99).
    Implemented by [Z.div] *)

val rem : t -> t -> t
(** Remainder of the truncated division towards 0 (like in C99).
    Implemented by [Z.rem] *)

val div_rem : t -> t -> t * t
(** [div_rem a b] returns [(div a b, rem a b)].
    Implemented by [Z.div_rem] *)

val pgcd : t -> t -> t
(** [pgcd v 0 == pgcd 0 v == abs v]. Result is always positive *)

val ppcm : t -> t -> t
(** [ppcm v 0 == ppcm 0 v == 0]. Result is always positive *)

val round_up_to_r : min:t -> r:t -> modu:t -> t
(** [round_up_to_r m r modu] is the smallest number [n] such that
    [n]>=[m] and [n] = [r] modulo [modu] *)

val round_down_to_r : max:t -> r:t -> modu:t -> t
(** [round_down_to_r m r modu] is the largest number [n] such that
    [n]<=[m] and [n] = [r] modulo [modu] *)

val popcount: t -> int

val hash : t -> int

val extract_bits : start:t -> stop:t -> t -> t
(** [extract_bits ~start ~stop v] is a shortcut for [Z.extract v pos length]
    where [pos] and [length] are computed using [start] and [stop].
*)

val cast: size:t -> signed:bool -> value:t -> t

(**************************************************************************)
(** {3 Printers} *)
(**************************************************************************)

(** Prints the integer in decimal format. See also {!pretty_hex}.

    @before 25.0-Manganese there was an optional [hexa] argument. *)
val pretty : t formatter

(** Prints the integer in hexadecimal format (replaces [hexa] optional
    argument of {!pretty} from older versions).

    @since 25.0-Manganese *)
val pretty_hex : t formatter

val pp_bin : ?nbits:int -> ?sep:string -> t formatter
(** Print binary format. Digits are output by blocs of 4 bits
    separated by [~sep] with at least [~nbits] total bits. If [nbits] is
    non positive, it will be ignored.

    Positive values are prefixed with ["0b"] and negative values
    are printed as their 2-complement ([lnot]) with prefix ["1b"]. *)

val pp_hex : ?nbits:int -> ?sep:string -> t formatter
(** Print hexadecimal format. Digits are output by blocs of 16 bits
    (4 hex digits) separated by [~sep] with at least [~nbits] total bits.
    If [nbits] is non positive, it will be ignored.

    Positive values are prefixed with ["0x"] and negative values
    are printed as their 2-complement ([lnot]) with prefix ["1x"]. *)

(**************************************************************************)
(** {3 Deprecated} *)
(**************************************************************************)

val two : t
[@@deprecated "Use '2z' instead."]
[@@migrate { repl = 2z } ]

val four : t
[@@deprecated "Use '4z' instead."]
[@@migrate { repl = 4z } ]

val eight : t
[@@deprecated "Use '8z' instead."]
[@@migrate { repl = 8z } ]

val sixteen : t
[@@deprecated "Use '1z6' instead."]
[@@migrate { repl = 16z } ]

val thirtytwo : t
[@@deprecated "Use '32z' instead."]
[@@migrate { repl = 32z } ]

val onethousand : t
[@@deprecated "Use '1000z' instead."]
[@@migrate { repl = 1000z } ]

val billion_one : t
[@@deprecated "Use '1_000_000_001_z' instead."]
[@@migrate { repl = 1_000_000_001_z } ]

val le : t -> t -> bool
[@@deprecated "Use leq instead."]
[@@migrate { repl = Rel.leq } ]

val ge : t -> t -> bool
[@@deprecated "Use geq instead."]
[@@migrate { repl = Rel.geq } ]


val two_power_32 : t
[@@deprecated "Use 'two_power_of_int 32' instead."]
[@@migrate { repl = Rel.two_power_of_int 32 } ]

val two_power_64 : t
[@@deprecated "Use 'two_power_of_int 64' instead."]
[@@migrate { repl = Rel.two_power_of_int 64 } ]

val max_int64 : t
[@@deprecated "Use 'of_int64 Int64.max_int' instead."]
[@@migrate { repl = Rel.of_int64 Int64.max_int } ]

val min_int64 : t
[@@deprecated "Use 'of_int64 Int64.min_int' instead."]
[@@migrate { repl = Rel.of_int64 Int64.min_int } ]

val e_div : t -> t -> t
(** Euclidean division (that returns a positive rem).
    Implemented by [Z.ediv]

    Equivalent to C division if both operands are positive.
    Equivalent to a floored division if b > 0 (rounds downwards),
    otherwise rounds upwards.
    Note: it is possible that e_div (-a) b <> e_div a (-b).
*)
[@@deprecated "Use ediv instead."]
[@@migrate { repl = Rel.ediv } ]

val e_rem : t -> t -> t
(** Remainder of the Euclidean division (always positive).
    Implemented by [Z.erem] *)
[@@deprecated "Use erem instead."]
[@@migrate { repl = Rel.erem } ]

val e_div_rem: t -> t -> (t * t)
(** [e_div_rem a b] returns [(e_div a b, e_rem a b)].
    Implemented by [Z.ediv_rem] *)
[@@deprecated "Use ediv_rem instead."]
[@@migrate { repl = Rel.ediv_rem } ]

val c_div : t -> t -> t
(** Truncated division towards 0 (like in C99).
    Implemented by [Z.div] *)
[@@deprecated "Use div instead."]
[@@migrate { repl = Rel.div } ]

val c_rem : t -> t -> t
(** Remainder of the truncated division towards 0 (like in C99).
    Implemented by [Z.rem] *)
[@@deprecated "Use rem instead."]
[@@migrate { repl = Rel.rem } ]

val c_div_rem : t -> t -> t * t
(** [c_div_rem a b] returns [(c_div a b, c_rem a b)].
    Implemented by [Z.div_rem] *)
[@@deprecated "Use div_rem instead."]
[@@migrate { repl = Rel.div_rem } ]
