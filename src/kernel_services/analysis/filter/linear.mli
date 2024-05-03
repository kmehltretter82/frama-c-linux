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



(* Definition of a linear space over a field. Used by Linear_filter to represent
   and compute linear filters invariants. *)

module Space (Field : Field.S) : sig

  (* The type of scalars in the field 𝕂. *)
  type scalar = Field.scalar

  (* The type of matrices in 𝕂ⁿˣᵐ *)
  type ('n, 'm) matrix

  (* Type representing a column vector of 𝕂ⁿ. One can use [transpose] if one
     needs a row vector, for example when printing it. *)
  type 'n vector = ('n, zero succ) matrix



  module Vector : sig

    val pretty : Format.formatter -> 'n vector -> unit

    (* The call [zero n] returns the 0 vector in 𝕂ⁿ. *)
    val zero   : 'n succ nat -> 'n succ vector

    (* The call [repeat x n] returns a vector in 𝕂ⁿ which each dimension
       containing the scalar x. *)
    val repeat : scalar -> 'n succ nat -> 'n succ vector

    (* The call [base i n] returns the i-th base vector in the orthonormal space
       of 𝕂ⁿ. In other words, the returned vector contains zero except for the
       i-th coordinate, which contains one. *)
    val base   : 'n succ finite -> 'n succ nat -> 'n succ vector

    (* The call [set i x v] returns a new vector of the same linear space as
       [v], and with the same coordinates, except for the i-th one, which is
       set to the scalar [x]. *)
    val set    : 'n finite -> scalar -> 'n vector -> 'n vector

    (* The call [size v] for [v] a vector of 𝕂ⁿ returns n. *)
    val size   : 'n vector -> 'n nat

    (* The call [norm v] computes the ∞-norm of [v], i.e the maximum of the
       absolute values of its coordinates. *)
    val norm   : 'n vector -> scalar

  end



  module Matrix : sig

    val pretty : Format.formatter -> ('n, 'm) matrix -> unit

    (* The call [id n] returns the identity matrix in 𝕂ⁿˣⁿ. *)
    val id : 'n succ nat -> ('n succ, 'n succ) matrix

    (* The call [zero n m] returns the 0 matrix in 𝕂ⁿˣᵐ. *)
    val zero : 'n succ nat -> 'm succ nat -> ('n succ, 'm succ) matrix

    (* The call [get i j m] returns the coefficient of the i-th row and
       the j-th column. *)
    val get : 'n finite -> 'm finite -> ('n, 'm) matrix -> scalar

    (* The call [set i j x m] returns a new matrix of the same linear space as
       [m], and with the same coefficients, except for the one of the i-th row
       and the j-th column, which is set to the scalar [x]. *)
    val set : 'n finite -> 'm finite -> scalar -> ('n, 'm) matrix -> ('n, 'm) matrix

    (* The call [norm m] computes the ∞-norm of [m], i.e the maximum of the
       absolute sums of the rows of [m]. *)
    val norm : ('n, 'm) matrix -> scalar

    (* The call [transpose m] for m in 𝕂ⁿˣᵐ returns a new matrix in 𝕂ᵐˣⁿ with
       all the coefficients transposed. *)
    val transpose : ('n, 'm) matrix -> ('m, 'n) matrix

    (* The call [dimensions m] for m in 𝕂ⁿˣᵐ returns the pair (n, m). *)
    val dimensions : ('m, 'n) matrix -> 'm nat * 'n nat

    (* Matrices addition. The dimensions compatibility is statically ensured. *)
    val ( + ) : ('n, 'm) matrix -> ('n, 'm) matrix -> ('n, 'm) matrix

    (* Matrices multiplication. The dimensions compatibility is statically
       ensured. *)
    val ( * ) : ('n, 'm) matrix -> ('m, 'p) matrix -> ('n, 'p) matrix

    (* Matrix exponentiation. The call [power m] returns a memoized function.
       When one needs to compute several exponentiations of the same matrix, one
       should perform the call [power m] once and used the returned function
       each times one needs it. *)
    val power : ('n, 'n) matrix -> (int -> ('n, 'n) matrix)

  end

end
