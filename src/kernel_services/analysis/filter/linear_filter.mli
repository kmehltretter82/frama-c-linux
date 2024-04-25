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

open Nat
open Finite

(* A filter corresponds to the recursive equation
   X[k + 1] = AX[k] + Bε[k + 1] + C where :
   - n is the filter's order and m its number of inputs ;
   - X[k] ∈ ℝ^n is the filter's state at iteration [k] ;
   - ε[k] ∈ ℝ^m is the filters's inputs at iteration [k] ;
   - A ∈ ℝ^(n×n) is the filter's state matrix ;
   - B ∈ ℝ^(n×m) is the filter's input matrix ;
   - C ∈ ℝ^n is the filter's center.

   The goal of this module is to compute filters invariants, i.e bounds for
   each of the filter's state dimensions when the iterations goes to infinity.
   To do so, it only suppose that, at each iteration, each input εi is bounded
   by [-λi .. λi]. Each input is thus supposed centered around zero but each
   one can have different bounds.

   {!Linear_filter_test} is an example using this module. *)
module Make (Field : Field.S) : sig

  module Linear : module type of Linear.Space (Field)

  (* A value of type [(n, m) filter] describes a linear filter of order n (i.e
     with n state variables) and with m inputs. *)
  type ('n, 'm) filter

  (* Create a filter's representation. The inputs are as following :
     - state is the filter's state matrix ;
     - input is the filter's input matrix ;
     - center is the filter's center ;
     - measure is a vector representing upper bounds for the filter's inputs. *)
  val create :
    state : ('n succ, 'n succ) Linear.matrix ->
    input : ('n succ, 'm succ) Linear.matrix ->
    center : 'n succ Linear.vector ->
    measure : 'm succ Linear.vector ->
    ('n succ, 'm succ) filter

  val pretty : Format.formatter -> ('n, 'm) filter -> unit

  (* Representation of a filter's invariant. Bounds for each dimension can be
     accessed using the corresponding functions. *)
  type 'n invariant
  val lower : 'n finite -> 'n invariant -> Field.scalar
  val upper : 'n finite -> 'n invariant -> Field.scalar
  val bounds : 'n finite -> 'n invariant -> Field.scalar * Field.scalar

  (* Invariant computation. The computation of [invariant filter k] relies on
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
     computation is immediate, even when using rational numbers. Indeed, the
     invariant computation complexity is bounded by O(kn^3 + mn^2) with [n]
     the filter's order and [m] its number of inputs. It is thus linear in
     the targeted exponent. *)
  val invariant : ('n, 'm) filter -> int -> 'n invariant option

end
