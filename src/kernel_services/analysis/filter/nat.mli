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

(* Encoding of the Peano arithmetic in OCaml type system. A value of type
   [n nat] contains [n] at the value and the type level, allowing to express
   properties on objects sizes and accesses for example. It is used by the
   module Linear to represent vectors and matrices dimensions. *)
type zero = |
type 'n succ = |
type 'n nat
type positive_or_null = PositiveOrNull : 'n nat -> positive_or_null
type strictly_positive = StrictlyPositive : 'n succ nat -> strictly_positive

val zero : zero nat
val one  : zero succ nat
val succ : 'n nat -> 'n succ nat
val prev : 'n succ nat -> 'n nat

(* The call [to_int n] returns an integer equal to n. This function complexity
   is O(1). *)
val to_int : 'n nat -> int

(* Returns a positive or null natural. If the given parameter is stricly
   negative then 0 is returned. This function complexity is O(n). *)
val of_int : int -> positive_or_null option

(* Returns a strictly positive natural. If the given parameter is less or equal
   than zero, then 1 is returned. This function complexity is O(n). *)
val of_strictly_positive_int : int -> strictly_positive option
