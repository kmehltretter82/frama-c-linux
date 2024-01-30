(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Nat.Types

module Make (Field : Field.S) : sig

  module Linear : module type of Linear.Space (Field)

  (* A value of type [(n, m) filter] describes a linear filter of order n (i.e
     with n state variables) and with m inputs. *)
  type ('n, 'm) filter

  val create :
    ('n succ, 'n succ) Linear.matrix ->
    ('n succ, 'm succ) Linear.matrix ->
    'm succ Linear.vector -> ('n succ, 'm succ) filter

  val pretty : Format.formatter -> ('n, 'm) filter -> unit

  (* Invariant computation. The computation of [invariant filter max] relies on
     the search of an exponent such as the norm of the state matrix is strictly
     lower than one. This search depth is bounded by [max]. If no exponent is
     found before this limit is reached, the function returns None. If an
     exponent [e] is found, the invariant computation complexity is bounded by
     O(e * (n^3 + n^2 * m)) with [n] the filter's order and [m] its number of
     inputs. Only the invariant's upper bound [λ] is returned, the filter's
     invariant is thus bounded by ±λ. The only thing that limit the optimality
     of this bound is [max], the initial search depth. However, for most simple
     filters, a depth of 200 will gives an exact upper bound up to at least ten
     digits, which is more than enough. Moreover, for those simple filters, the
     computation is immediate, even when using rational numbers. *)
  val invariant : ('n, 'm) filter -> int -> Field.scalar option

end
