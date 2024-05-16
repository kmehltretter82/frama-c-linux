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

type 'n finite = int

let first  : type n. n succ finite = 0
let last   : type n. n succ nat -> n succ finite = fun n -> Nat.to_int n - 1
let next   : type n. n finite -> n succ finite = fun n -> n + 1
let ( = )  : type n. n finite -> n finite -> bool = fun l r -> l = r
let to_int : type n. n finite -> int = fun n -> n

let of_int : type n. n succ nat -> int -> n succ finite option =
  fun limit n -> if 0 <= n && n < Nat.to_int limit then Some n else None

let for_each (type n) (f : n finite -> 'a -> 'a) (limit : n nat) acc =
  let acc = ref acc in
  for i = 0 to Nat.to_int limit - 1 do acc := f i !acc done ;
  !acc
