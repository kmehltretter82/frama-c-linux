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
  if a = 0 then abs b else
  if b = 0 then abs a else
    gcd b (a mod b)

let (%.) = gcd

(* -------------------------------------------------------------------------- *)
(* --- Range Maps                                                         --- *)
(* -------------------------------------------------------------------------- *)

type 'a range = {
  offset: int ;
  length: int ;
  data: 'a ;
}

let pp_range fmt r =
  Format.fprintf fmt "%04d..%04d" r.offset (r.offset + r.length - 1)

let pp_offset fmt r =
  Format.fprintf fmt "%04d:%04d" r.offset r.length

type 'a t = R of 'a range list (* sorted, no-overlap *)

let empty = R []

let singleton r =
  if not (0 <= r.offset && 0 < r.length) then
    raise (Invalid_argument "Region.Ranges.singleton") ;
  R [r]

let range ?(offset=0) ?(length=1) data = singleton { offset ; length ; data }

let rec find (k: int) = function
  | [] -> raise Not_found
  | ({ offset ; length } as r) :: rs ->
    if offset <= k && k <= offset + length then r else find k rs

let find k (R rs) = find k rs

let rec merge f ra rb =
  match ra, rb with
  | [], rs | rs, [] -> rs
  | a :: wa, b :: wb ->
    let a' = a.offset + a.length in
    let b' = b.offset + b.length in
    if a' <= b.offset then
      a :: merge f wa rb
    else
    if b' < a.offset then
      b :: merge f ra wb
    else
      let offset = min a.offset b.offset in
      let length = max a' b' - offset in
      let data = f a b in
      let r = { offset ; length ; data } in
      if a' < b'
      then merge f wa (r::wb)
      else merge f (r::wa) wb

let merge f (R x) (R y) = R (merge f x y)

let squash f = function
  | R [] -> None
  | R (x::xs) -> Some (List.fold_left (fun w r -> f w r.data) x.data xs)

let iteri f (R xs) = List.iter f xs
let iter f (R xs) = List.iter (fun r -> f r.data) xs
let map f (R xs) = R (List.map (fun r -> { r with data = f r.data }) xs)

(* -------------------------------------------------------------------------- *)
