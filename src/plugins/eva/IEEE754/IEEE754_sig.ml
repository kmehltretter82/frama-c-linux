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

(** This module provides the type definitions and module signatures used by
    the {!IEEE754} module to build an abstract semantics of floating-point
    computations as defined by the IEEE-754 standard. See this module for
    more information. *)

open Lattice_bounds
open Typed_float
open Field



(** {2 Miscellaneous definitions.} *)

(** Type encoding correctly rounded operations. Values of this type are
    provided to the model when asked to represent elementary rounding errors.
    Relational abstractions may use them to keep track of the relations
    between rounding errors during the analysis. *)
type 'a correctly_rounded_expression =
  | Cast of 'a
  | Sqrt of 'a
  | Add of 'a * 'a
  | Sub of 'a * 'a
  | Mul of 'a * 'a
  | Div of 'a * 'a

(** Existential type on format. *)
type resulting_format =
  | Format : 'f format -> resulting_format

(** Abstract values may be context dependent, which can be easily represented
    using a monad. This signature extends monads signature with a [resolve]
    function, that must be able to concretize a monadic computation on a
    given context. *)
module type Computation = sig
  type context
  include Monad.S_with_product
  val resolve : context -> 'a t -> 'a
end



(** {2 Abstract representation of subsets over a field.} *)

module type Abstraction = sig

  (** {3 The field over which the abstraction is defined.} *)

  module Scalar : Field.S
  type scalar = Scalar.t


  (** {3 The monad used to encode context dependent computations.} *)

  module Computation : Computation
  type 'a computation = 'a Computation.t


  (** {3 Datatype and type alias.} *)

  include Datatype.S
  type subset = t


  (** {3 Constants and constructors.} *)

  val zero : subset
  val one  : subset

  (** The call [singleton r] returns the abstract representation of the
      singleton subset containing [r]. *)
  val singleton : scalar -> subset

  (** The call [between l r] returns the abstract representation of the
      subset containing all scalars between [l] and [u] included. *)
  val between   : scalar -> scalar -> subset


  (** {3 Lattice structure.} *)

  val top         : subset
  val is_included : subset -> subset -> bool
  val join        : subset -> subset -> subset
  val narrow      : subset -> subset -> subset or_bottom


  (** {3 Projection into an interval.}
      The [lower] and [upper] functions are provided as convenience. *)

  val bounds : subset -> scalar bounds
  val lower  : subset -> scalar
  val upper  : subset -> scalar


  (** {3 Arithmetic operations.} *)

  val neg   : subset computation -> subset computation
  val sqrt  : subset computation -> subset computation
  val ( + ) : subset computation -> subset computation -> subset computation
  val ( - ) : subset computation -> subset computation -> subset computation
  val ( * ) : subset computation -> subset computation -> subset computation
  val ( / ) : subset computation -> subset computation -> subset computation


  (** {3 Backward reductions.} *)

  (** The call [backward_lower ~left ~right] returns a reduced abstraction
      of [left] based on the assumption that [left <= right]. If the assumption
      is wrong because no concrete element of [left] can possibly be lower
      than or equal to any concrete element of [right], the function must
      return [`Bottom]. *)
  val backward_left_lower : left : subset -> right : subset -> subset or_bottom

  (** The call [backward_greater ~left ~right] returns a reduced abstraction
      of [left] based on the assumption that [left >= right]. If the assumption
      is wrong because no concrete element of [left] can possibly be greater
      than or equal to any concrete element of [right], the function must
      return [`Bottom]. *)
  val backward_left_greater : left : subset -> right : subset -> subset or_bottom

end



(** {2 Modeling used to abstract the IEEE-754 semantics.} *)

module type Modeling = sig

  (** {3 The field over which the abstraction is defined.} *)

  module Scalar : Field.S
  type scalar = Scalar.t


  (** {3 The monad used to encode context dependent computations.}
      It must rely on a context that respects {!Abstract_context.Leaf}. *)

  module Context : Abstract_context.Leaf
  module Computation : Computation with type context = Context.t
  type 'a computation = 'a Computation.t


  (** {3 Abstraction used for the exact and absolute errors semantics.} *)

  module Additive : Abstraction
    with module Scalar = Scalar
     and module Computation = Computation

  module Exact = Additive
  type exact = Exact.subset

  module Absolute = Additive
  type absolute = Absolute.subset


  (** {3 Abstraction used for the relative errors semantics.} *)

  module Multiplicative : Abstraction
    with module Scalar = Scalar
     and module Computation = Computation

  module Relative = Multiplicative
  type relative = Relative.subset


  (** {3 Reduced product and other miscellaneous values.} *)

  (** Name of the resulting abstract domain. *)
  val name : string

  (** The call [new_absolute_elementary_error expr bound] returns a computation
      of the absolute abstraction of the elementary rounding error that would
      be produced by the computation of [expr] and is bounded by [bound]. *)
  val new_absolute_elementary_error :
    exact correctly_rounded_expression -> scalar -> absolute computation

  (** The call [new_relative_elementary_error expr bound] returns a computation
      of the relative abstraction of the elementary rounding error that would
      be produced by the computation of [expr] and is bounded by [bound]. *)
  val new_relative_elementary_error :
    exact correctly_rounded_expression -> scalar -> relative computation

  (** The call [do_reduce_absolute_with_relative ()] returns [true] if and only
      if the analysis is configured to reduce the absolute errors using the
      relative error bounds. *)
  val do_reduce_absolute_with_relative : unit -> bool

  (** The call [do_reduce_relative_with_absolute ()] returns [true] if and only
      if the analysis is configured to reduce the relative errors using the
      absolute error bounds. *)
  val do_reduce_relative_with_absolute : unit -> bool

  (** The call [recompute_absolute exact relative] returns a computation of
      absolute error bounds as deduced from [exact] and [relative], respectively
      representing the exact semantics and the relative error semantics. It will
      be used if the reduced product is configured to reduce the absolute errors
      using the relative error bounds. *)
  val recompute_absolute :
    exact    : exact    ->
    relative : relative ->
    absolute computation

  (** The call [recompute_relative exact absolute] returns a computation of
      relative error bounds as deduced from [exact] and [absolute], respectively
      representing the exact semantics and the absolute error semantics. It will
      be used if the reduced product is configured to reduce the relative errors
      using the absolute error bounds. *)
  val recompute_relative :
    exact    : exact    ->
    absolute : absolute ->
    relative computation

  (** This function is used to compute an abstraction of [(ax + by) / (x + y)],
      as this expression can be more precisely abstracted using a dedicated
      approach than the straightforward composition of arithmetic operators.
      In the context of the IEEE-754 semantics, those expressions appear in
      the relative error semantics of the addition, which is why the function
      is specialized on relative abstractions. *)
  val a_x_plus_b_y_over_x_plus_y :
    a : relative -> x : exact ->
    b : relative -> y : exact ->
    relative computation

end
