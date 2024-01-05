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

module Types = struct
  type zero = |
  type 'n succ = |
  type 'n nat = Zero : zero nat | Succ : 'n nat -> 'n succ nat
  type positive_or_null = PositiveOrNull : 'n nat -> positive_or_null
  type strictly_positive = StrictlyPositive : 'n succ nat -> strictly_positive
end

open Types

let zero = Zero
let one  = Succ Zero
let succ n = (Succ n)
let prev (Succ n) = n

let to_int n =
  let rec aux : type n. int -> n nat -> int = fun acc ->
    function Zero -> acc | Succ n -> aux (acc + 1) n
  in aux 0 n

let of_int n =
  let next (PositiveOrNull n) = PositiveOrNull (Succ n) in
  let rec aux acc n = if n <= 0 then acc else aux (next acc) (n - 1) in
  aux (PositiveOrNull zero) n

let of_strictly_positive_int n =
  let next (StrictlyPositive n) = StrictlyPositive (Succ n) in
  let rec aux acc n = if n <= 1 then acc else aux (next acc) (n - 1) in
  aux (StrictlyPositive one) n
