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

type 'a t = 'a data ref
and 'a data = Memory of 'a array | Diff of int * 'a * 'a t

let init n f = ref (Memory (Array.init n f))

let rec reroot t =
  match !t with
  | Memory mem -> mem
  | Diff (i, v, t') ->
    let mem = reroot t' in
    let v' = Array.get mem i in
    Array.set mem i v ;
    t  := Memory mem ;
    t' := Diff (i, v', t) ;
    mem

let pretty ?(sep = format_of_string " ") pp fmt t =
  let mem = reroot t in
  for i = 0 to Array.length mem - 1 do
    if i > 0 then Format.fprintf fmt sep ;
    pp fmt mem.(i)
  done

let get t i =
  match !t with
  | Memory mem -> Array.get mem i
  | Diff _ -> Array.get (reroot t) i

let set t i v =
  let mem = reroot t in
  let old = Array.get mem i in
  Array.set mem i v ;
  let res = ref (Memory mem) in
  t := Diff (i, old, res) ;
  res

let fold f t acc =
  let mem = reroot t and index = ref 0 in
  let f' acc v = let acc = f !index v acc in incr index ; acc in
  Array.fold_left f' acc mem

let map f t =
  let mem = reroot t |> Array.copy in
  let res = ref t in
  for i = 0 to Array.length mem - 1 do
    res := set !res i (f mem.(i))
  done ;
  !res
