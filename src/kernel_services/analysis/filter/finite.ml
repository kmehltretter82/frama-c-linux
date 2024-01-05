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
  type 'n finite = First : 'n succ finite | Next : 'n finite -> 'n succ finite
end

open Types

let rec weaken : type n. n finite -> n succ finite =
  function First -> First | Next n -> Next (weaken n)

let rec of_int : type n. n succ nat -> int -> n succ finite = fun limit n ->
  match limit with
  | Succ Zero -> First
  | Succ (Succ _) when n <= 0 -> First
  | Succ (Succ limit) -> Next (of_int (Succ limit) (n - 1))

let to_int finite =
  let rec aux : type n. int -> n finite -> int = fun acc ->
    function First -> acc | Next n -> aux (acc + 1) n
  in aux 0 finite

let rec of_nat : type n. n succ nat -> n succ finite = function
  | Succ Zero -> First
  | Succ (Succ n) -> Next (of_nat (Succ n))

let rec fold f n acc =
  match n with
  | First -> f First acc
  | Next n -> f (Next n) (fold f (weaken n) acc)

let for_each (type n) acc (n : n nat) (f : n finite -> 'a -> 'a) =
  match n with Zero -> acc | Succ _ as n -> fold f (of_nat n) acc
