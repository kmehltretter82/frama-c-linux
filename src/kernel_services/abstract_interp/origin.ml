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
let unknown = Unknown
let is_unknown t = t = Unknown

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

include Datatype.Make_with_collections (Prototype)

let pretty_as_reason fmt org =
  if not (is_unknown org)
  then Format.fprintf fmt " because of %a" pretty org

let descr = function
  | Unknown -> "unknown origin"
  | Well -> "well in initial state"
  | Origin { kind } ->
    match kind with
    | Misalign_read -> "misaligned read of addresses"
    | Leaf -> "assigns clause on addresses"
    | Merge -> "imprecise merge of addresses"
    | Arith -> "arithmetic operation on addresses"

let join t1 t2 =
  if t1 == t2 then t1 else
    match t1, t2 with
    | Unknown, x | x, Unknown -> x
    | Well, _ | _, Well -> Well
    | Origin o1, Origin o2 -> if o1.id <= o2.id then t1 else t2

let is_included = equal

let is_current = function
  | Unknown | Well -> false
  | Origin { loc } -> Cil_datatype.Location.equal loc (Cil.CurrentLoc.get ())


module History_Info = struct
  let name = "Origin.History"
  let dependencies = []
  let size = 32
end

module History_Data =
  Datatype.Triple (Datatype.Int) (Datatype.Int) (Base.SetLattice)
module History = State_builder.Hashtbl (Hashtbl) (History_Data) (History_Info)

let clear () = Id.reset (); History.clear ()

let register_write bases t =
  if is_unknown t then false else
    let change (w, r, b) = w+1, r, Base.SetLattice.join b bases in
    let count, _, _ = History.memo ~change (fun _ -> 1, 0, bases) t in
    count < 2 && is_current t

let register_read bases t =
  if not (is_unknown t || is_current t) then
    let change (w, r, b) = w, r+1, Base.SetLattice.join b bases in
    ignore (History.memo ~change (fun _ -> 0, 1, bases) t)


let get_history () =
  let list = List.of_seq (History.to_seq ()) in
  let list = List.filter (fun (_origin, (_, r, _)) -> r > 0) list in
  let cmp (origin1, (_, r1, _)) (origin2, (_, r2, _)) =
    let r = r2 - r1 in
    if r <> 0 then r else compare origin1 origin2
  in
  List.sort cmp list

let pretty_origin fmt origin =
  match origin with
  | Unknown -> Format.fprintf fmt "Unknown origin"
  | Well -> Format.fprintf fmt "Initial state"
  | Origin { loc } ->
    Format.fprintf fmt "%a: %s"
      Cil_datatype.Location.pretty loc (descr origin)

let pretty_history fmt =
  let list = get_history () in
  let pp_origin fmt (origin, (w, r, bases)) =
    let bases = Base.SetLattice.filter (fun b -> not (Base.is_null b)) bases in
    Format.fprintf fmt
      "@[<hov 2>%a@ (read %i times, propagated %i times)@ \
       garbled mix of &%a@]"
      pretty_origin origin r w Base.SetLattice.pretty bases
  in
  if list <> [] then
    Format.fprintf fmt
      "@[<v 2>Origins of garbled mix generated during analysis:@,%a@]"
      (Pretty_utils.pp_list ~sep:"@," pp_origin) list

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
