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

let rec gcd a b =
  if a = Int64.zero then Int64.abs b else
  if b = Int64.zero then Int64.abs a else
    gcd b (Int64.rem a b)

let (+.) = Int64.add
let (-.) = Int64.sub
let (%.) = gcd

(* -------------------------------------------------------------------------- *)
(* --- Range Maps                                                         --- *)
(* -------------------------------------------------------------------------- *)

type 'a range = {
  offset: int64 ;
  length: int64 ;
  data: 'a ;
}

type 'a t = R of 'a range list (* sorted, no-overlap *)

let empty = R []

let singleton r = R [r]

let rec find (k: int64) = function
  | [] -> raise Not_found
  | ({ offset ; length } as r) :: rs ->
    if offset <= k && k <= offset +. length then r else find k rs

let find k (R rs) = find k rs

let rec merge f ra rb =
  match ra, rb with
  | [], rs | rs, [] -> rs
  | a :: wa, b :: wb ->
    let a' = a.offset +. a.length in
    let b' = b.offset +. b.length in
    if a' <= b.offset then
      a :: merge f wa rb
    else
    if b' < a.offset then
      b :: merge f ra wb
    else
      let offset = min a.offset b.offset in
      let length = max a' b' -. offset in
      let data = f a b in
      let r = { offset ; length ; data } in
      if a' < b'
      then merge f ra (r::rb)
      else merge f (r::ra) rb

let merge f (R x) (R y) = R (merge f x y)

let iteri f (R xs) = List.iter f xs
let iter f (R xs) = List.iter (fun r -> f r.data) xs

(* -------------------------------------------------------------------------- *)
