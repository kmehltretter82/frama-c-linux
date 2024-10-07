(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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
(* --- Proxy to Region Analysis for Region Model                          --- *)
(* -------------------------------------------------------------------------- *)

type region = Region.node

let get_map () =
  match WpContext.get_scope () with
  | Kf kf -> Region.map kf
  | Global -> Wp_parameters.not_yet_implemented "[region] logic context"

let id region = Region.uid (get_map ()) region

let of_id id =
  try Some (Region.find (get_map ()) id)
  with Not_found -> None

module Type =
struct
  type t = region
  let hash = Region.id
  let equal r1 r2 = (Region.id r1 = Region.id r2)
  let compare r1 r2 = Int.compare (Region.id r1) (Region.id r2)
  let pretty fmt r = Format.fprintf fmt "R%03d" @@ Region.id r
end

let types r =
  let module Tset = Cil_datatype.Typ.Set in
  let pool = ref Tset.empty in
  let add ty = pool := Tset.add ty !pool in
  let map = get_map () in
  List.iter add @@ Region.reads map r ;
  List.iter add @@ Region.writes map r ;
  List.iter add @@ Region.shifts map r ;
  Tset.elements !pool

(* Keeping track of the decision to apply which memory model to each region *)
module Kind = WpContext.Generator(Type)
    (struct
      (* Data : WpContext.Data with type key = Key.t *)
      type key = region
      type data = MemRegion.kind
      let name = "Wp.RegionAnalysis.R"
      let compile region =
        let open MemRegion in
        match types region with
        | [ty] ->
          begin
            match Ctypes.object_of ty with
            | C_int i -> Many (Int i)
            | C_float f -> Many (Float f)
            | C_pointer _ -> Many Ptr
            | _ -> Garbled
          end
        | _ -> Garbled
    end)

let kind = Kind.get
let points_to region = Region.points_to (get_map ()) region
let separated r1 r2 = Region.separated (get_map ()) r1 r2
let included r1 r2 = Region.included (get_map ()) r1 r2

let cvar var =
  try Some (Region.cvar (get_map ()) var)
  with Not_found -> None

let field r fd =
  try Some (Region.field (get_map ()) r fd)
  with Not_found -> None

let shift r obj =
  try Some (Region.index (get_map ()) r (Ctypes.object_to obj))
  with Not_found -> None

let literal ~eid _ = ignore eid ; None
