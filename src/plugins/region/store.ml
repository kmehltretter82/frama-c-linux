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

(* -------------------------------------------------------------------------- *)
(* --- UnionFind Store with explicit integer keys                         --- *)
(* -------------------------------------------------------------------------- *)

module Imap = Map.Make(Int)

type 'a rref = int
type 'a store = {
  mutable rid : int ;
  mutable map : 'a Imap.t ;
}

let new_store () = { rid = 0 ; map = Imap.empty }
let copy r = { rid = r.rid ; map = r.map }

let make s v =
  let k = succ s.rid in
  s.rid <- k ; s.map <- Imap.add k v s.map ; k

let get s k = Imap.find k s.map
let set s k v = s.map <- Imap.add k v s.map

let eq _s i j = (i == j)

let id x = x
let forge x = x
let list = List.sort_uniq Int.compare
let rec bag a b =
  match a, b with
  | [], c | c, [] -> c
  | x::xs, y::ys -> x :: y :: bag xs ys
