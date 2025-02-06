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

(** This module provides a generic signature describing mathematical fields,
    i.e algebraic structure that behave like rationals, reals or complex
    numbers. The signature also provides several functions that are not
    directly part of fields definition, but are useful nonetheless, in
    particular when using fields to model floating point computations.
    @since Frama-C+dev *)

(** This type is used to return bounds for mathematical functions that
    cannot be exactly computed using rationals, like the square root
    for instance. *)
type 't bounds = { lower : 't ; upper : 't }

module type S = sig

  include Datatype.S_with_collections
  type scalar = t

  (** {2 Useful constants in the field.}

      Two is provided for users that model floating point computations using
      abstractions over the field. *)

  val zero    : scalar
  val one     : scalar
  val two     : scalar
  val pos_inf : scalar
  val neg_inf : scalar

  (** {2 Constructors interacting with standard OCaml types.} *)

  val of_int    : int -> scalar
  val of_float  : float -> scalar
  val to_float  : scalar -> float
  val of_string : string -> scalar

  (** {2 Standard arithmetic unary operations.} *)

  val neg : scalar -> scalar
  val abs : scalar -> scalar

  (** {2 Standard arithmetic binary operations.} *)

  val ( + ) : scalar -> scalar -> scalar
  val ( - ) : scalar -> scalar -> scalar
  val ( * ) : scalar -> scalar -> scalar
  val ( / ) : scalar -> scalar -> scalar

  (** {2 Standard arithmetic relational operations.} *)

  val ( =  ) : scalar -> scalar -> bool
  val ( != ) : scalar -> scalar -> bool
  val ( <= ) : scalar -> scalar -> bool
  val ( <  ) : scalar -> scalar -> bool
  val ( >= ) : scalar -> scalar -> bool
  val ( >  ) : scalar -> scalar -> bool

  (** {2 Other arithmetic operations. }*)

  (** [pow2 e] computes the scalar [2 ^ e]. *)
  val pow2 : int -> scalar

  (** [log2 f] computes the integer [l] and [u] such as
      [l = floor(log₂ f)] and [u = ceiling(log₂ f)]. *)
  val log2 : scalar -> int bounds

  (** [sqrt f] computes bounds of the square root of [f]. *)
  val sqrt : scalar -> scalar bounds

  val max : scalar -> scalar -> scalar
  val min : scalar -> scalar -> scalar

end
