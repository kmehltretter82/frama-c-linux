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

(** Interface for the Region plug-in. *)


open Cil_types


(* General type *)
type region
module R : Qed.Collection.S with type t = region
type map

(* API GETTERS *)
val get_map : kernel_function -> map

val cvar : map -> varinfo -> region
val field : map -> region -> fieldinfo -> region
val index : map -> region -> typ -> region

val region_of_ptr_term : map -> term -> region

(* API POINTERS *)
val points_to : map -> region -> region option
val pointed_by : map -> region -> region list

(* API ITERATOR *)
val iter : map -> (region -> unit) -> unit


(* API PRINTER *)
val pp_region : Format.formatter -> region -> unit


(* API ACCESS *)
type acs = {
  acs_read  : typ list;
  acs_write : typ list;
  acs_shift : typ list;
}
val empty_acs : acs
val accesses : region -> acs
