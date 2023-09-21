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
  | Misalign_read
  | Leaf
  | Merge
  | Arith

let kind_rank = function
  | Misalign_read -> 0
  | Leaf -> 1
  | Merge -> 2
  | Arith -> 3

let kind_label = function
  | Misalign_read -> "Misaligned"
  | Leaf -> "Library function"
  | Merge -> "Merge"
  | Arith -> "Arithmetic"

type location = Cil_datatype.Location.t

type tt =
  | Origin of { kind: kind; loc: location; id: int; }
  | Well
  | Unknown

module Id = State_builder.Counter (struct let name = "Origin.Id" end)

let current kind =
  let id = Id.next () in
  let loc = Cil.CurrentLoc.get () in
  Origin { kind; loc; id; }

let well = Well
let top = Unknown
let is_top t = t = Unknown

module Prototype = struct
  include Datatype.Serializable_undefined
  type t = tt
  let name = "Origin"
  let reprs = [ Unknown ]

  let compare t1 t2 =
    match t1, t2 with
    | Origin o1, Origin o2 ->
      if o1.kind = o2.kind
      then Cil_datatype.Location.compare o1.loc o2.loc
      else kind_rank o2.kind - kind_rank o1.kind
    | Well, Well | Unknown, Unknown -> 0
    | Origin _, _ | Well, Unknown -> 1
    | _, Origin _ | Unknown, Well -> -1

  let equal = Datatype.from_compare

  let hash = function
    | Well -> 0
    | Unknown -> 1
    | Origin { kind; loc; } ->
      Hashtbl.hash (kind_rank kind, Cil_datatype.Location.hash loc) + 2

  let pretty fmt = function
    | Well -> Format.fprintf fmt "Well"
    | Unknown -> Format.fprintf fmt "Unknown"
    | Origin { kind; loc; } ->
      let pretty_loc = Cil_datatype.Location.pretty in
      Format.fprintf fmt "%s@ {%a}" (kind_label kind) pretty_loc loc
end

include Datatype.Make (Prototype)

let pretty_as_reason fmt org =
  if not (is_top org)
  then Format.fprintf fmt " because of %a" pretty org

let join t1 t2 =
  if t1 == t2 then t1 else
    match t1, t2 with
    | Unknown, x | x, Unknown -> x
    | Well, _ | _, Well -> Well
    | Origin o1, Origin o2 -> if o1.id <= o2.id then t1 else t2

let is_included = equal

(* Well and Unknown origins have no location information.
   Leaf origins are also imprecise, because we may create tons of those,
   that get reduced to precise values by the specifications of the function. *)
let is_precise = function
  | Unknown | Well -> false
  | Origin { kind } -> kind <> Leaf

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
