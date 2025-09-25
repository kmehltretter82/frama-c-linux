(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** This module aims to provide overapproximations of the behaviors of
    linear time-invariant (LTI) filters, for both the transition and
    the permanent phases.

    A LTI filter corresponds to the following recursive equation :
      {math X[t + 1] = AX[t] + Bε[t] + S}
    where :
    - {m 𝕂} is a field ;
    - {m n} is the filter's state dimension, or order ;
    - {m m} is the filter's measure space dimension ;
    - {m X[t] ∈ 𝕂^n} is the filter's state vector at iteration {m t} ;
    - {m ε[t] ∈ 𝕂^m} is a measure vector at iteration {m t} ;
    - {m A ∈ 𝕂^{n × n}} is the state matrix ;
    - {m B ∈ 𝕂^{n × m}} is the measure matrix ;
    - {m S ∈ 𝕂^n} is the filter's shift.

    Several notes here :
    - The only hypothesis on {m A} is that its eigenvalues are all lower
      than one in absolute value. It is a sufficient condition for the
      filter to converge. Conversely, there is no hypothesis on {m B}.
      If the procedure cannot prove easily that this hypothesis is
      satisfied, it will simply return [None].
    - All measure vectors are supposed belonging to a box subset of {m 𝕂^m}
      described by a center vector and a radius vector.
    - In most presentations of LTI filters, the presented system is
      described using two equations, a recursive one equivalent to the
      one presented here and focused on the hidden state vector, and
      an output non recursive equation focused on transforming the hidden
      state vector into a usable output. However, as the two equations can
      be easily combined into one, it is not considered in this module.
    - Moreover, the filter's shift is usually not present, as it makes
      the system kind of an affine time-invariant filter. However, the
      theory underlying this module can easily take it into account, and
      thus make it more general.

    A complete documentation on the underlying theory will be added in a
    near future. For an example using this module, one can check
    {!Linear_filter_test}. *)

module Make (K : Field.S) : sig

  (** The linear space in which the filters are defined. *)
  module Linear : module type of Linear.Space (K)
  open Linear
  open Nat

  (** A value of type [(n, m) filter] describes a LTI filter with a state
      space of dimension [n] and a measure space of dimension [m]. *)
  type ('n, 'm) filter

  (** Filters constructor. The inputs are as following :
      - [initial] is the filter's initial state, i.e {m X[0]} ;
      - [shift] is the filter's shift, called {m S} above ;
      - [measure_center] is the center of the box containing the measures ;
      - [measure_radius] is the radius of the box containing the measures ;
      - [measure_matrix] is the measure matrix, called {m B} above ;
      - [state_matrix] is the state matrix, called {m A} above. *)
  val create :
    initial        : 'n succ vector ->
    shift          : 'n succ vector ->
    measure_center : 'm succ vector ->
    measure_radius : 'm succ vector ->
    measure_matrix : ('n succ, 'm succ) matrix ->
    state_matrix   : ('n succ, 'n succ) matrix ->
    ('n succ, 'm succ) filter

  (** Representation of a LTI filter's behavior. The fields are as follows
      - [transition] represents the transition phase as a list of bounds,
        one for each iteration that cannot be proven contained in the
        permanent phase. The length of the list, i.e the number of unrolled
        iterations, depends on the filter's parameters and on the precision
        of the permanent phase's abstraction.
      - [permanent] represents the permanent phase a a unique bounds, which
        is an invariant for the filter for all iterations after the one
        unrolled through the transition phase. *)
  type 'n behavior = { transition : 'n bounds list ; permanent : 'n bounds }
  and  'n bounds = 'n vector Field.bounds

  (** Behavior computation. As stated above, a complete documentation of the
      underlying theory will be provided. The optionnal parameters are as
      follows :
      - [timeout] specifies the maximum analysis duration. It is expressed
        in seconds, and its default value is one second.
      - [maximal_unrolling] specifies the maximum number of iterations that
        are accepted for the transition phase. Its default value is 200. *)
  val behavior :
    ?timeout : float ->
    ?maximal_unrolling : int ->
    ('n succ, 'm succ) filter ->
    'n succ behavior option

end
