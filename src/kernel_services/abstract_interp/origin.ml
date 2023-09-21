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

type kind =
  | K_Misalign_read
  | K_Leaf
  | K_Merge
  | K_Arith

module Location = Cil_datatype.Location

module LocationLattice = struct

  type t = Top | Bottom | Value of Location.t

  module Datatype_Input = struct
    include Datatype.Serializable_undefined

    type nonrec t = t
    let name = "Origin.LocationLattice"
    let reprs = [ Top ]
    let structural_descr =
      Structural_descr.t_sum [| [| Location.packed_descr |] |]

    let compare l1 l2 =
      match l1, l2 with
      | Top, Top | Bottom, Bottom -> 0
      | Value loc1, Value loc2 -> Location.compare loc1 loc2
      | Top, _ -> 1
      | _, Top -> -1
      | Bottom, _ -> -1
      | _, Bottom -> 1

    let equal l1 l2 =
      match l1, l2 with
      | Top, Top | Bottom, Bottom -> true
      | Value loc1, Value loc2 -> Location.equal loc1 loc2
      | _ -> false

    let hash = function
      | Top -> 3
      | Bottom -> 5
      | Value loc -> Location.hash loc * 7

    let pretty fmt = function
      | Top -> Format.fprintf fmt "Top"
      | Bottom ->  Format.fprintf fmt "Bottom"
      | Value loc -> Format.fprintf fmt "{%a}" Location.pretty loc
  end

  include (Datatype.Make (Datatype_Input) : Datatype.S with type t := t)

  let current_loc () = Value (Cil.CurrentLoc.get ())

  let join l1 l2 =
    if l1 == l2 then l1 else
      match l1, l2 with
      | Top, _ | _, Top -> Top
      | Bottom , l | l, Bottom -> l
      | Value loc1, Value loc2 ->
        if Location.equal loc1 loc2 then l1 else Top

  let narrow l1 l2 =
    if l1 == l2 then l1 else
      match l1, l2 with
      | Bottom, _ | _, Bottom -> Bottom
      | Top , l | l, Top -> l
      | Value loc1, Value loc2 ->
        if Location.equal loc1 loc2 then l1 else Bottom

  let meet = narrow
end

type origin =
  | Misalign_read of LocationLattice.t
  | Leaf of LocationLattice.t
  | Merge of LocationLattice.t
  | Arith of LocationLattice.t
  | Well
  | Unknown

let well = Well

let current = function
  | K_Misalign_read -> Misalign_read (LocationLattice.current_loc ())
  | K_Leaf -> Leaf (LocationLattice.current_loc ())
  | K_Merge -> Merge (LocationLattice.current_loc ())
  | K_Arith -> Arith (LocationLattice.current_loc ())

let equal o1 o2 = match o1, o2 with
  | Well, Well | Unknown, Unknown -> true
  | Leaf o1, Leaf o2 | Arith o1, Arith o2 | Merge o1, Merge o2
  | Misalign_read o1, Misalign_read o2  ->
    LocationLattice.equal o1 o2
  | Misalign_read _, _ -> false
  | _, Misalign_read _ -> false
  |  Leaf _, _ -> false
  |  _, Leaf _ -> false
  | Merge _, _ -> false
  | _, Merge _ -> false
  | Arith _, _ -> false
  | _, Arith _ -> false
  | _, Well | Well, _ -> false

let compare o1 o2 = match o1, o2 with
  | Misalign_read s1, Misalign_read s2
  | Leaf s1, Leaf s2
  | Merge s1, Merge s2
  | Arith s1, Arith s2 ->
    LocationLattice.compare s1 s2

  | Well, Well | Unknown, Unknown -> 0

  | Misalign_read _, (Leaf _ | Merge _ | Arith _ | Well | Unknown)
  | Leaf _, (Merge _ | Arith _ | Well | Unknown)
  | Merge _, (Arith _ | Well | Unknown)
  | Arith _, (Well | Unknown)
  | Well, Unknown ->
    -1

  | Unknown, (Well | Arith _ | Merge _ | Leaf _ | Misalign_read _)
  | Well, (Arith _ | Merge _ | Leaf _ | Misalign_read _)
  | Arith _, (Merge _ | Leaf _ | Misalign_read _)
  | Merge _, (Leaf _ | Misalign_read _)
  | Leaf _, Misalign_read _
    -> 1

let top = Unknown
let is_top x = equal top x


let pretty_source fmt = function
  | LocationLattice.Top -> () (* Hide unhelpful 'TopSet' *)
  | LocationLattice.Value _ | LocationLattice.Bottom as s ->
    Format.fprintf fmt "@ %a" LocationLattice.pretty s

let pretty fmt o = match o with
  | Unknown ->
    Format.fprintf fmt "Unknown"
  | Misalign_read o ->
    Format.fprintf fmt "Misaligned%a" pretty_source o
  | Leaf o ->
    Format.fprintf fmt "Library function%a" pretty_source o
  | Merge o ->
    Format.fprintf fmt "Merge%a" pretty_source o
  | Arith o ->
    Format.fprintf fmt "Arithmetic%a" pretty_source o
  | Well ->       Format.fprintf fmt "Well"

let pretty_as_reason fmt org =
  if not (is_top org) then
    Format.fprintf fmt " because of %a" pretty org


let hash o = match o with
  | Misalign_read o ->
    2001 +  (LocationLattice.hash o)
  | Leaf o ->
    2501 + (LocationLattice.hash o)
  | Merge o ->
    3001 + (LocationLattice.hash o)
  | Arith o ->
    3557 + (LocationLattice.hash o)
  | Well -> 17
  | Unknown -> 97

include Datatype.Make
    (struct
      type t = origin
      let name = "Origin"
      let structural_descr = Structural_descr.t_unknown
      let reprs = [ Well; Unknown ]
      let compare = compare
      let equal = equal
      let hash = hash
      let rehash = Datatype.undefined
      let copy = Datatype.undefined
      let pretty = pretty
      let mem_project = Datatype.never_any_project
    end)

let bottom = Arith LocationLattice.Bottom

let join o1 o2 =
  let result =
    if o1 == o2
    then o1
    else
      match o1, o2 with
      | Unknown,_ | _, Unknown -> Unknown
      | Well,_ | _ , Well   -> Well
      | Misalign_read o1, Misalign_read o2 ->
        Misalign_read(LocationLattice.join o1 o2)
      | _, (Misalign_read _ as m) | (Misalign_read _ as m), _ -> m
      | Leaf o1, Leaf o2 ->
        Leaf(LocationLattice.join o1 o2)
      | (Leaf _ as m), _ | _, (Leaf _ as m) -> m
      | Merge o1, Merge o2 ->
        Merge(LocationLattice.join o1 o2)
      | (Merge _ as m), _ | _, (Merge _ as m) -> m
      | Arith o1, Arith o2 ->
        Arith(LocationLattice.join o1 o2)
        (* | (Arith _ as m), _ | _, (Arith _ as m) -> m *)
  in
  (*  Format.printf "Origin.join %a %a -> %a@." pretty o1 pretty o2 pretty result;
  *)
  result

let link = join

let meet o1 o2 =
  if o1 == o2
  then o1
  else
    match o1, o2 with
    | Arith o1, Arith o2 ->
      Arith(LocationLattice.meet o1 o2)
    | (Arith _ as m), _ | _, (Arith _ as m) -> m
    | Merge o1, Merge o2 ->
      Merge(LocationLattice.meet o1 o2)
    | (Merge _ as m), _ | _, (Merge _ as m) -> m
    | Leaf o1, Leaf o2 ->
      Leaf(LocationLattice.meet o1 o2)
    | (Leaf _ as m), _ | _, (Leaf _ as m) -> m
    | Misalign_read o1, Misalign_read o2 ->
      Misalign_read(LocationLattice.meet o1 o2)
    | _, (Misalign_read _ as m) | (Misalign_read _ as m), _ -> m
    | Well, Well -> Well
    | Well,m | m, Well -> m
    | Unknown, Unknown -> Unknown

let narrow o1 o2 =
  if o1 == o2
  then o1
  else
    match o1, o2 with
    | Arith o1, Arith o2 -> Arith (LocationLattice.narrow o1 o2)
    | Merge o1, Merge o2 -> Merge (LocationLattice.narrow o1 o2)
    | Leaf o1, Leaf o2 -> Leaf (LocationLattice.narrow o1 o2)
    | Misalign_read o1, Misalign_read o2 ->
      Misalign_read (LocationLattice.narrow o1 o2)
    | Well, Well -> Well
    | Unknown, m | m, Unknown -> m
    | _, _ -> Unknown

let is_included o1 o2 =
  (equal o1 (meet o1 o2))


(* Well and Unknown origins have no location information.
   Leaf origins are also imprecise, because we may create tons of those,
   that get reduced to precise values by the specifications of the function. *)
let is_precise = function
  | Well | Unknown | Leaf _ -> false
  | Misalign_read _ | Merge _ | Arith _ -> true


(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
