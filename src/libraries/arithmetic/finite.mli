(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
    [strengthen n f] allows to prove that fact to the type system. [None]
    is returned if and only if [f] is the last element of its subset. *)
val strengthen : 'n nat -> 'n succ finite -> 'n finite option

(** The call [of_int limit n] returns a finite value representing the nth
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
