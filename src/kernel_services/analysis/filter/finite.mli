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



(* The type [n finite] encodes all finite sets of cardinal [n]. It is used by
   the module Linear to represent accesses to vectors and matrices coefficients,
   statically ensuring that no out of bounds access can be performed. *)
type 'n finite

val first : 'n succ finite
val last  : 'n succ nat -> 'n succ finite
val next  : 'n finite -> 'n succ finite
val ( = ) : 'n finite -> 'n finite -> bool

(* The call [of_int limit n] returns a finite value representing the n-nd
   element of a finite set of cardinal limit. If n is not in the bounds, none is
   returned. This function complexity is O(1). *)
val of_int : 'n succ nat -> int -> 'n succ finite option

(* The call [to_int n] returns an integer equal to n. This function complexity
   is O(1). *)
val to_int : 'n finite -> int

(* The call [for_each acc limit f] folds over each finite elements of a set of
   cardinal limit, computing f at each step. The function complexity is O(n). *)
val for_each : ('n finite -> 'a -> 'a) -> 'n nat -> 'a -> 'a
