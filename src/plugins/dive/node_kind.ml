(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `Dive'.                      *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

open Graph_types

module DatatypeInput =
struct
  include Datatype.Undefined

  type t = node_kind

  let (<?>) c (cmp,x,y) =
    if c = 0
    then cmp x y
    else c

  let name = "Node_kind"

  let reprs = [ Scalar (
      List.hd Cil_datatype.Varinfo.reprs,
      List.hd Cil_datatype.Typ.reprs,
      List.hd Cil_datatype.Offset.reprs) ]

  let compare k1 k2 =
    let open Cil_datatype in
    match k1, k2 with
    | Scalar (vi1, _, offset1), Scalar (vi2, _, offset2) ->
      Varinfo.compare vi1 vi2 <?> (OffsetStructEq.compare, offset1, offset2)
    | Scalar _, _ -> 1
    | _, Scalar _ -> -1
    | Composite vi1, Composite vi2 -> Varinfo.compare vi1 vi2
    | Composite _, _ -> 1
    | _, Composite _ -> -1
    | Scattered (lv1,loc1), Scattered (lv2,loc2) ->
      LvalStructEq.compare lv1 lv2 <?> (Locations.Location.compare, loc1, loc2)
    | Scattered _, _ -> 1
    | _, Scattered _ -> -1
    | Alarm (stmt1, alarm1), Alarm (stmt2, alarm2) ->
      Stmt.compare stmt1 stmt2 <?> (Alarms.compare, alarm1, alarm2)

  let equal k1 k2 =
    let open Cil_datatype in
    match k1, k2 with
    | Scalar (vi1, _, offset1), Scalar (vi2, _, offset2) ->
      Varinfo.equal vi1 vi2 && OffsetStructEq.equal offset1 offset2
    | Composite vi1, Composite vi2 -> Varinfo.equal vi1 vi2
    | Scattered (lv1, loc1), Scattered (lv2, loc2) ->
      LvalStructEq.equal lv1 lv2 && Locations.Location.equal loc1 loc2
    | Alarm (stmt1, alarm1), Alarm (stmt2, alarm2) ->
      Stmt.equal stmt1 stmt2 && Alarms.equal alarm1 alarm2
    | _ -> false

  let hash k =
    let open Cil_datatype in
    match k with
    | Scalar (vi, _, offset) ->
      Hashtbl.hash (1, Varinfo.hash vi, OffsetStructEq.hash offset)
    | Composite vi -> Hashtbl.hash (2, Varinfo.hash vi)
    | Scattered (lv, loc) ->
      Hashtbl.hash (3, LvalStructEq.hash lv, Locations.Location.hash loc)
    | Alarm (stmt, alarm) ->
      Hashtbl.hash (4, Stmt.hash stmt, Alarms.hash alarm)
end

include Datatype.Make (DatatypeInput)


let get_base = function
  | Scalar (vi,_,_) | Composite (vi) -> Some vi
  | Scattered _ | Alarm _ -> None

let to_location = function
  | Scalar (vi,typ,offset) ->
    let base = Base.of_varinfo vi in
    Some (Locations.loc_of_typoffset base typ offset)
  | Composite (vi) ->
    Some (Locations.loc_of_varinfo vi)
  | Scattered (_,loc) ->
    Some loc
  | Alarm _  -> None

let to_lval = function
  | Scalar (vi,_typ,offset) -> Some (Cil_types.Var vi, offset)
  | Composite (vi) -> Some (Cil_types.Var vi, Cil_types.NoOffset)
  | Scattered (lval,_) -> Some lval
  | Alarm (_,_) -> None

let pretty fmt = function
  | (Scalar _ | Composite _ | Scattered _) as kind ->
    Cil_printer.pp_lval fmt (Extlib.the (to_lval kind))
  | Alarm (_stmt,alarm) ->
    Cil_printer.pp_predicate fmt (Alarms.create_predicate alarm)
