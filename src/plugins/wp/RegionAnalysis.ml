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

open Cil_types
open Ctypes
open Lang.F

type region = Region.node

let get_map () = match WpContext.get_scope () with
  | WpContext.Kf f   -> Region.map f
  | WpContext.Global -> Wp_parameters.not_yet_implemented "[WP/RegionAnalysis.ml] get_map: No global region analysis yet"

let null () : region =
  Warning.emit ~severe:false ~source:"Region Memory Model"
    ~effect:"Create null pointer value" "NULL" ;
  Wp_parameters.not_yet_implemented "[WP/RegionAnalysis.ml] null: cannot create null region"

let id_of_region region = Region.uid (get_map ()) region

let region_of_id id =
  try Some (Region.find (get_map ()) id)
  with Not_found -> None

let hash = Region.id

let equal r1 r2 = (Region.id r1 = Region.id r2)

let compare r1 r2 = Int.compare (Region.id r1) (Region.id r2)

let pretty fmt r = Format.fprintf fmt "R%03d" @@ Region.id r

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
module Kind = WpContext.Generator
    (struct
      (* Key : WPContext.Key *)
      type t = region
      let compare = compare
      let pretty = pretty
    end)
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

let tau_of_region region : tau =
  match types region with
  | [ ty ] -> Lang.tau_of_ctype ty
  | _ -> (*TODO*) assert false

let points_to region = Region.points_to (get_map ()) region

let separated r1 r2 = Region.separated (get_map ()) r1 r2

let included r1 r2 = Region.included (get_map ()) r1 r2

let cvar var =
  try Some (Region.cvar (get_map ()) var)
  with Not_found ->
    Warning.emit ~severe:false ~source:"RegionAnalysis.cvar"
      ~effect:"No region found for C variable" "%a" Printer.pp_varinfo var ;
    None

let field (region: region) (fd: fieldinfo) : region option =
  try Some (Region.field (get_map ()) region fd)
  with Not_found ->
    Warning.emit ~severe:false
      ~source:"RegionAnalysis.field"
      ~effect:"No region found for field"
      "No region for field %a from region %a"
      Printer.pp_field fd pretty region;
    None

let shift region ty offset =
  let rec aux = function
    | [] ->
      Warning.emit ~severe:false
        ~source:"RegionAnalysis.shift"
        ~effect:"No region found"
        "No region for shift %a from region %a"
        QED.pretty offset pretty region;
      None
    | typ :: rest ->
      try Some (Region.index (get_map ()) region typ)
      with Not_found -> aux rest
  in aux @@ Ctypes.object_to ty

let base_addr _ = assert false
let literal ~eid _ = ignore eid ; assert false
let pointer_loc () = assert false
let loc_of_int () = assert false
