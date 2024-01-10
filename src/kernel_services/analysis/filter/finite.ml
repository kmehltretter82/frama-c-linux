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

module Types = struct
  type 'n formal = First : 'n succ formal | Next : 'n formal -> 'n succ formal
  type 'n finite = { value : int ; formal : 'n formal }
end

open Types

let first = { value = 0 ; formal = First }
let next { value ; formal } = { value = value + 1 ; formal = Next formal }
let to_int { value ; _ } = value
let ( == ) l r = l.value = r.value

let rec of_int : type n. n succ nat -> int -> n succ finite = fun limit n ->
  match limit with
  | Succ Zero -> first
  | Succ Succ _ when n <= 0 -> first
  | Succ Succ limit -> next (of_int (Succ limit) (n - 1))

let rec of_nat : type n. n succ nat -> n succ finite = function
  | Succ Zero -> first
  | Succ (Succ n) -> next (of_nat (Succ n))

(* We use Obj.magic here to avoid the O(n) long but trivial proof *)
let weaken : type n. n finite -> n succ finite =
  fun { value ; formal } -> { value ; formal = Obj.magic formal }

(* Non tail-rec to perform the computation in the natural order *)
let rec fold f n acc =
  match n with
  | { formal = First ; _ } as n -> f n acc
  | { formal = Next formal ; value } as n ->
    f n (fold f (weaken { value = value - 1 ; formal }) acc)

let for_each (type n) acc (n : n nat) (f : n finite -> 'a -> 'a) =
  match n with Zero -> acc | Succ _ as n -> fold f (of_nat n) acc
