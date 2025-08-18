(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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

let new_store () = { rid = 0 ; map = Imap.empty  }
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
