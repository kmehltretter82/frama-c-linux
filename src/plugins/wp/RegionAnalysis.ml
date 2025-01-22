(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
let compare r1 r2 = Int.compare (Region.id r1) (Region.id r2)
let pretty fmt r = Format.fprintf fmt "R%03d" @@ Region.id r

module R =
struct
  type t = region
  let compare = compare
  let pretty = pretty
end

(* Keeping track of the decision to apply which memory model to each region *)
module Kind = WpContext.Generator(R)
    (struct
      open MemRegion
      let name = "Wp.RegionAnalysis.Kind"
      type key = region
      type data = kind
      let kind map r p = if Region.singleton map r then Single p else Many p
      let compile r =
        let map = get_map () in
        match Region.typed map r with
        | Some ty ->
          begin
            match Ctypes.object_of ty with
            | C_int i -> kind map r (Int i)
            | C_float f -> kind map r (Float f)
            | C_pointer _ -> kind map r Ptr
            | _ -> Garbled
          end
        | None -> Garbled
    end)

module Name = WpContext.Generator(R)
    (struct
      let name = "Wp.RegionAnalysis.Name"
      type key = region
      type data = string option
      let compile r =
        let map = get_map () in
        match Region.labels map r with
        | label::_ -> Some label
        | [] ->
          match Region.roots map r with
          | v::_ -> Some v.vorig_name
          | _ -> None
    end)

let kind = Kind.get
let name = Name.get
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

let footprint r = Region.footprint (get_map ()) r
