(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Compute filters invariants, i.e bounds for each of the filter's state
    dimensions when the iterations goes to infinity.

    A filter corresponds to the following recursive equation :
       {math X[t + 1] = AX[t] + ∑B(ω)ε(ω)[k + 1] + C }
    where :
    - {m n} is the filter's order ;
    - {m ω} is a measure's source (for instance, a specific sensor in a
      cyberphysical system) ;
    - {m m(ω)} is the delay for the source {m ω} ;
    - {m X[t] ∈ 𝕂^n} is the filter's state at iteration [t] ;
    - {m ε(ω)[t] ∈ 𝕂^{m(ω)}} is the measure at iteration [t] for the source {m ω} ;
    - {m A ∈ 𝕂^{nxn}} is the filter's state matrix ;
    - {m B(ω) ∈ 𝕂^{nxm(ω)}} is the source matrix for the source {m ω} ;
    - {m C ∈ 𝕂^n} is the filter's center.

    To compute filter invariants, each measure of a given source is supposed
    bounded by the same interval, represented as a center and a deviation. Each
    source can thus be bounded by a different interval.

    {!Linear_filter_test} is an example using this module. *)

module Make (Field : Field.S) : sig

  (** The linear space in which the filters are defined. *)
  module Linear : module type of Linear.Space (Field)
  open Finite
  open Nat


  (** A source describes a source of measures, for instance a specific sensor,
      that is treated at each iteration by the filter. Measures can be centered
      around any scalar, and are thus described by a center and a deviation. The
      source's delay is hidden inside the type. *)
  type 'n source

  (** Sources constructor. The inputs are as following :
      - [matrix] is the source matrix, describing how the current and past
        measures are taken into account ;
      - [center] is the measures center ;
      - [deviation] is the measures deviation. *)
  val source :
    matrix    : ('n succ, 'm succ) Linear.matrix ->
    center    : Field.scalar ->
    deviation : Field.scalar ->
    'n succ source

  (** A value of type [n filter] describes a filter of order [n] (i.e with [n] state
      variables). The sources delays are contained by each one of them. *)
  type 'n filter

  (** Filters constructors. The inputs are as following :
      - [center] is the filter's center ;
      - [state] is the filter's state matrix ;
      - [sources] is the list of the filter's sources. *)
  val create :
    state   : ('n succ, 'n succ) Linear.matrix ->
    center  : 'n succ Linear.vector ->
    sources : 'n succ source list ->
    'n succ filter

  (** Filters pretty printer. *)
  val pretty : Format.formatter -> 'n filter -> unit


  (** Representation of a filter's invariant. Bounds for each dimension can be
      accessed using the corresponding functions. *)
  type 'n invariant
  val lower  : 'n finite -> 'n invariant -> Field.scalar
  val upper  : 'n finite -> 'n invariant -> Field.scalar
  val bounds : 'n finite -> 'n invariant -> Field.scalar * Field.scalar


  (** Invariant computation. The computation of [invariant filter k] relies on
      the search of an exponent such as the norm of the state matrix is strictly
      lower than one. For the filter to converge, there must exist an α such as,
      for every β greater than α, ||A^β|| < 1 with A the filter's state matrix.
      As such, the search does not have to find α, but instead any exponent such
      as the property is satisfied. As the computed invariant will be more
      precise with a larger exponent, the computation always uses [k], the
      largest authorized exponent, and thus only check that indeed ||A^k|| < 1.
      If the property is not verified, the function returns None as it cannot
      prove that the filter converges.

      The only thing limiting the invariant optimality is [k]. However, for most
      simple filters, k = 200 will gives exact bounds up to at least ten digits,
      which is more than enough. Moreover, for those simple filters, the
      computation is immediate, even when using rational numbers. *)
  val invariant : 'n filter -> int -> 'n invariant option

end
