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

type lpath = {
  loc : location ;
  ltype : typ ;
  lnode : lnode ;
}

and lnode =
  | L_var of varinfo
  | L_region of string
  | L_addr of lpath
  | L_star of lpath
  | L_index of lpath
  | L_shift of lpath
  | L_field of lpath * fieldinfo
  | L_cast of typ * lpath

type region = {
  rname: string option ;
  rpath: lpath list ;
}

val pp_lnode : Format.formatter -> lnode -> unit
val pp_latom : Format.formatter -> lpath -> unit
val pp_lpath : Format.formatter -> lpath -> unit
val pp_region : Format.formatter -> region -> unit
val pp_regions : Format.formatter -> region list -> unit

val of_extension : acsl_extension -> region list
val of_code_annot : code_annotation -> region list
val of_behavior : behavior -> region list
