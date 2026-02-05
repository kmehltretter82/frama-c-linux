(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

type spec = {
  loc  : location ;
  typ  : typ ;
  step : step ;
}

and step =
  | Var of varinfo
  | AddrOf of spec
  | Star of spec
  | Shift of spec
  | Index of spec * int (* size *)
  | Field of spec * fieldinfo
  | Cast of typ * spec

type region = {
  name : string option ;
  spec : spec list ;
}

val pp_step : Format.formatter -> step -> unit
val pp_atom : Format.formatter -> spec -> unit
val pp_path : Format.formatter -> spec -> unit
val pp_region : Format.formatter -> region -> unit
val pp_regions : Format.formatter -> region list -> unit

val of_extid : int -> region list
val of_extension : acsl_extension -> region list
val of_code_annot : code_annotation -> region list
val of_behavior : behavior -> region list
