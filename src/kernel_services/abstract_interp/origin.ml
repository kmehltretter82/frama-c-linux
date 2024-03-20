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
  | Misalign_write
  | Leaf
  | Merge
  | Arith

let kind_rank = function
  | Misalign_read -> 0
  | Misalign_write -> 1
  | Leaf -> 2
  | Merge -> 3
  | Arith -> 4

let kind_label = function
  | Misalign_read -> "Misaligned read"
  | Misalign_write -> "Misaligned write"
  | Leaf -> "Library function"
  | Merge -> "Merge"
  | Arith -> "Arithmetic"

(* Ideally, we would use the current statement sid instead of the current
   source file location. However, that would require passing the current
   statement through any datastructures and operations that can create
   garbled mixes, which would be an invasive change. *)
type location = Cil_datatype.Location.t

type tt =
  | Origin of { kind: kind; loc: location; id: int; }
  | Well
  | Unknown

(* Unique id for each origin. Used to keep the oldest origin when a garbled
   mix may have several origins. *)
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
    | Misalign_write -> "misaligned write of addresses"
    | Leaf -> "assigns clause on addresses"
    | Merge -> "imprecise merge of addresses"
    | Arith -> "arithmetic operation on addresses"

(* Keep the oldest known origin: it is probably the most relevant origin, as
   subsequent ones may have been created because of the first. *)
let join t1 t2 =
  if t1 == t2 then t1 else
    match t1, t2 with
    | Unknown, x | x, Unknown -> x
    | Well, _ | _, Well -> Well
    | Origin o1, Origin o2 -> if o1.id <= o2.id then t1 else t2


(* For each garbled mix origin, keep track of:
   - the number of writes (according to [register_write] below), i.e. the number
     of times a garbled mix with this origin has been written in a state during
     the analysis.
   - the number of reads (according to [register_read] below), i.e. the number
     of times a garbled mix with this origin is used by the analysis.
     Only reads at a different location than that of the origin are counted:
     if a garbled mix is only used where it has been created, it has no more
     impact on the analysis precision than any other imprecise value.
   - the set of bases related to garbled mix with this origin.

   These info are printed at the end of an Eva analysis. *)

module History_Info = struct
  let name = "Origin.History"
  let dependencies = []
  let size = 32
end

module LocSet = Cil_datatype.Location.Set

(* Locations of writes, locations of reads, related bases. *)
module History_Data = Datatype.Triple (LocSet) (LocSet) (Base.SetLattice)
module History = State_builder.Hashtbl (Hashtbl) (History_Data) (History_Info)

let clear () = Id.reset (); History.clear ()

let is_current = function
  | Unknown | Well -> false
  | Origin { loc } -> Cil_datatype.Location.equal loc (Cil.CurrentLoc.get ())

(* Returns true if the origin has never been registered and is related to the
   current location. *)
let register_write bases t =
  if is_unknown t then false else
    let current_loc = Cil.CurrentLoc.get () in
    let is_new = not (History.mem t) in
    let change (w, r, b) =
      LocSet.add current_loc w, r, Base.SetLattice.join b bases
    in
    let create _ = LocSet.singleton current_loc, LocSet.empty, bases in
    ignore (History.memo ~change create t);
    is_new && is_current t

(* Registers a read only if the current location is not that of the origin. *)
let register_read bases t =
  if not (is_unknown t || is_current t) then
    let current_loc = Cil.CurrentLoc.get () in
    let change (w, r, b) =
      w, LocSet.add current_loc r, Base.SetLattice.join b bases
    in
    let create _ = LocSet.empty, LocSet.singleton current_loc, bases in
    ignore (History.memo ~change create t)

(* Returns the list of recorded origins, sorted by number of reads.
   Origins with no reads are filtered. *)
let get_history () =
  let list = List.of_seq (History.to_seq ()) in
  let count (origin, (w, r, bases)) =
    if LocSet.is_empty r
    then None
    else Some (origin, (LocSet.cardinal w, LocSet.cardinal r, bases))
  in
  let list = List.filter_map count list in
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
  let plural count = if count = 1 then "" else "s" in
  let pp_origin fmt (origin, (w, r, bases)) =
    let bases = Base.SetLattice.filter (fun b -> not (Base.is_null b)) bases in
    Format.fprintf fmt
      "@[<hov 2>%a@ (read in %i statement%s, propagated through %i statement%s)@ \
       garbled mix of &%a@]"
      pretty_origin origin r (plural r) w (plural w) Base.SetLattice.pretty bases
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
