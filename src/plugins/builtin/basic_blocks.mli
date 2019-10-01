(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
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

open Cil_types

val ptr_of: typ -> typ
val const_of: typ -> typ

val size_t: unit -> typ

val string_of_typ: typ -> string

val ttype_of_pointed: logic_type -> logic_type

val cvar_to_tvar: varinfo -> term
val tunref_range: ?loc:location -> term -> term -> term
val tplus: ?loc:location -> term -> term -> term
val tminus: ?loc:location -> term -> term -> term
val tdivide: ?loc:location -> term -> term -> term

val pvalid_len_bytes: ?loc:location -> logic_label -> term -> term -> predicate
val pvalid_read_len_bytes: ?loc:location -> logic_label -> term -> term -> predicate
val pcorrect_len_bytes: ?loc:location -> logic_type -> term -> predicate
val punfold_all_elems_eq: ?loc:location -> term -> term -> term -> predicate

val pseparated_memories: ?loc:location -> term -> term -> term -> term -> predicate

val plet_len_div_size:
  ?loc:location -> logic_type -> term -> (term -> predicate) -> predicate

val make_behavior:
  ?name:string ->
  ?assumes:identified_predicate list ->
  ?requires:identified_predicate list ->
  ?ensures:(termination_kind * identified_predicate) list ->
  ?assigns:assigns ->
  ?alloc:allocation ->
  ?extension:acsl_extension list ->
  unit ->
  behavior

val make_funspec:
  behavior list ->
  ?termination:identified_predicate option ->
  ?complete_disjoint:(string list list * string list list) ->
  unit ->
  funspec
