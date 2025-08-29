(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
