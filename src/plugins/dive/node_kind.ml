(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `Dive'.                      *)
(*                                                                        *)
(*  Copyright (C) 2018                                                    *)
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

let get_base = function
  | Scalar (vi,_,_) | Composite (vi) -> Some vi
  | Scattered _ | Alarm _ | File -> None

let to_location = function
  | Scalar (vi,typ,offset) ->
    let base = Base.of_varinfo vi in
    Some (Locations.loc_of_typoffset base typ offset)
  | Composite (vi) ->
    Some (Locations.loc_of_varinfo vi)
  | Scattered _ | Alarm _ | File -> None

let to_lval = function
  | Scalar (vi,_typ,offset) -> Some (Cil_types.Var vi, offset)
  | Composite (vi) -> Some (Cil_types.Var vi, Cil_types.NoOffset)
  | Scattered (lval) -> Some lval
  | Alarm (_,_) | File -> None

let pretty fmt = function
  | (Scalar _ | Composite _ | Scattered _) as kind ->
    Cil_printer.pp_lval fmt (Extlib.the (to_lval kind))
  | Alarm (_stmt,alarm) ->
    Cil_printer.pp_predicate fmt (Alarms.create_predicate alarm)
  | File -> ()
