(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

open Cil_types

type path = {
  loc : location ;
  typ : typ ;
  step: step ;
}

and step =
  | Var of varinfo
  | AddrOf of path
  | Star of path
  | Shift of path
  | Index of path * int
  | Field of path * fieldinfo
  | Cast of typ * path

type region = {
  rname: string option ;
  rpath: path list ;
}

val pp_step : Format.formatter -> step -> unit
val pp_atom : Format.formatter -> path -> unit
val pp_path : Format.formatter -> path -> unit
val pp_region : Format.formatter -> region -> unit
val pp_regions : Format.formatter -> region list -> unit

val of_extension : acsl_extension -> region list
val of_code_annot : code_annotation -> region list
val of_behavior : behavior -> region list
