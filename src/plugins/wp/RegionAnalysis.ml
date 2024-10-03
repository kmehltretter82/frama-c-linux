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


(* -------------------------------------------------------------------------- *)
(* --- Region Analysis API for Region Memory Model                        --- *)
(* -------------------------------------------------------------------------- *)

module type API = sig
  type region
  val null : unit -> region


  val hash : region -> int
  val equal : region -> region -> bool
  val compare : region -> region -> int
  val pretty : Format.formatter -> region -> unit

  type primitive = | Int of c_int | Float of c_float | Ptr
  type kind = Single of primitive | Many of primitive | Garbled
  val kind : region -> kind
  val pp_kind : Format.formatter -> kind -> unit

  val tau_of_region : region -> tau
  val points_to : region -> region option

  val separated : region -> region -> bool
  val included : region -> region -> bool

  val cvar : varinfo -> region option
  val field : region -> fieldinfo -> region option
  val shift : region -> c_object -> term -> region option
  val base_addr : region -> region

  val literal : eid:int -> Cstring.cst -> region option
  val pointer_loc : unit -> region option
  val loc_of_int : unit -> region option

  val id_of_region : region -> int
  val region_of_id : int -> region option
end


(* -------------------------------------------------------------------------- *)
(* --- Region Analysis for Region Memory Model                            --- *)
(* -------------------------------------------------------------------------- *)

module R (*: API*) =
struct

  type region = Region.node

  let get_map () = match WpContext.get_scope () with
    | WpContext.Kf f   -> Region.get_map f
    | WpContext.Global -> Wp_parameters.not_yet_implemented "[WP/RegionAnalysis.ml] get_map: No global region analysis yet"

  let null () : region =
    Warning.emit ~severe:false ~source:"Region Memory Model"
      ~effect:"Create null pointer value" "NULL" ;
    Wp_parameters.not_yet_implemented "[WP/RegionAnalysis.ml] null: cannot create null region"


  let id_of_region region = Region.get_uid (get_map ()) region

  let region_of_id id =
    try Some (Region.get_node (get_map ()) id)
    with Not_found -> None

  let hash = Region.get_id

  let equal r1 r2 = (Region.get_id r1 = Region.get_id r2)

  let compare r1 r2 = Int.compare (Region.get_id r1) (Region.get_id r2)

  let pretty fmt r = Format.fprintf fmt "R%03d" @@ Region.get_id r

  type primitive = | Int of c_int | Float of c_float | Ptr
  type kind = Single of primitive | Many of primitive | Garbled

  let pp_primitive fmt = function
    | Int i -> Ctypes.pp_int fmt i
    | Float f -> Ctypes.pp_float fmt f
    | Ptr -> Format.pp_print_string fmt "void*"
  let pp_kind fmt = function
    | Many p -> Format.fprintf fmt "[%a]" pp_primitive p
    | Single p -> pp_primitive fmt p
    | Garbled -> Format.pp_print_string fmt "Garbled"

  module CollectionCObject = Qed.Collection.Make(struct
      type t      = Ctypes.c_object
      let compare = Ctypes.compare
      let hash    = Ctypes.hash
      let equal   = Ctypes.equal
    end)

  module CObjects = CollectionCObject.Set

  let types r =
    let map = get_map () in
    let add_type set ty = CObjects.add (Ctypes.object_of ty) set in
    let types = CObjects.empty in
    let types = List.fold_left add_type types @@ Region.reads map r in
    let types = List.fold_left add_type types @@ Region.writes map r in
    let types = List.fold_left add_type types @@ Region.shifts map r in
    types

  (** Internal handling of region kinds *)
  module KindCompile = struct
    (* Data : WpContext.Data with type key = Key.t *)
    type key = region
    type data = kind
    let name = "WP.RegionAnalysis.R"
    let compile region : kind = match CObjects.elements @@ types region with
      | [] ->
        Warning.emit ~severe:false ~source:"RegionAnalysis.KindCompile.compile"
          ~effect:"Access type list is empty" "%a" pretty region ;
        Garbled
      | [ Ctypes.C_int cint ]     -> Many (Int cint)
      | [ Ctypes.C_float cfloat ] -> Many (Float cfloat)
      | [ Ctypes.C_pointer _ ]    -> Many Ptr
      | [ Ctypes.C_comp _ ]       -> Garbled
      | [ Ctypes.C_array _ ]      -> Garbled
      | _ :: _ :: _               -> Garbled
  end


  (* Keeping track of the decision to apply which memory model to each region *)
  module Kind = WpContext.Generator(struct
      (* Key : WPContext.Key *)
      type t = region
      let compare = compare
      let pretty = pretty
    end)(KindCompile)

  let kind = Kind.get


  let tau_of_region region : tau = match CObjects.elements @@ types region with
    | _ :: _ :: _ ->
      Warning.emit ~severe:false ~source:"RegionAnalysis.tau_of_region"
        ~effect:"Access type list is more than a singleton" "%a" pretty region ;
      assert false
    | [] ->
      Warning.emit ~severe:false ~source:"RegionAnalysis.tau_of_region"
        ~effect:"Access type list is empty" "%a" pretty region ;
      assert false
    | [ ty ] -> Lang.tau_of_object ty

  let points_to region = Region.points_to (get_map ()) region

  (*

        if not (Layout.fits ~dst:s.post ~src:s.pre) then
          Warning.emit ~severe:false ~source:"Region Memory Model"
            ~effect:"Keep pointer value"
            "%a" pp_mismatch s ; l


  *)

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

end
