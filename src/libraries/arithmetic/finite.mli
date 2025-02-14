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

open Nat

(** Encoding of finite set in OCaml type system. *)

(** The type [n finite] encodes all finite sets of cardinal [n]. It is used by
    the module {!Linear} to represent accesses to vectors and matrices
    coefficients, statically ensuring that no out of bounds access can be
    performed. *)
type 'n finite

(** The first element of any finite subset. The type encodes that for a finite
    subset to have an element, its cardinal must be at least one. *)
val first  : 'n succ finite

(** [last n] returns a value encoding the last element of any
    finite subset of cardinal [n]. *)
val last   : 'n succ nat -> 'n succ finite

(** The call [next f] returns a value encoding the element right after [f] in
    a finite subset. The type encodes the relations between the cardinal of
    the finite subset containing [f] and the cardinal of the one containing
    its successor. *)
val next   : 'n finite -> 'n succ finite

(** The call [prev f] returns a value encoding the element right before [f] in
    a finite subset. The type encodes the relations between the cardinal of
    the finite subset containing [f] and the cardinal of the one containing
    its predecessor. *)
val prev   : 'n succ finite -> 'n finite

(** If [f] is an element of any finite subset of cardinal [n], it is also an
    element of any finite subset of cardinal [n + 1]. The call [weaken f]
    allows to prove that fact to the type system. *)
val weaken : 'n finite -> 'n succ finite

(** If [f] is an element of any finite subset of cardinal [n + 1], it may
    also be an element of any finite subset of cardinal [n]. The call
    [strengten n f] allows to prove that fact to the type system. [None]
    is returned if and only if [f] is the last element of its subset. *)
val strenghten : 'n nat -> 'n succ finite -> 'n finite option

(** The call [of_int limit n] returns a finite value representing the n-nd
    element of a finite set of cardinal limit. If n is not in the bounds, [None]
    is returned. This function complexity is O(1). *)
val of_int : 'n succ nat -> int -> 'n succ finite option

(** The call [to_int n] returns an integer equal to n. This function complexity
    is O(1). *)
val to_int : 'n finite -> int

(** The call [for_each f limit acc] folds over each finite elements of a set of
    cardinal limit, computing f at each step.
    The function complexity is O(n). *)
val for_each : ('n finite -> 'a -> 'a) -> 'n nat -> 'a -> 'a

(** {2 Relational operators.} *)

val ( =  ) : 'n finite -> 'n finite -> bool
val ( != ) : 'n finite -> 'n finite -> bool
val ( <  ) : 'n finite -> 'n finite -> bool
val ( <= ) : 'n finite -> 'n finite -> bool
val ( >  ) : 'n finite -> 'n finite -> bool
val ( >= ) : 'n finite -> 'n finite -> bool
