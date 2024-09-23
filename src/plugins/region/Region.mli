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


(* Lower level API - more efficient *)
module Node : sig
  (* General type *)
  type node
  type map

  (* API GETTERS *)
  val get_map : kernel_function -> map

  val get_id : map -> node -> int
  val get_node : map -> int -> node

  val cvar : map -> varinfo -> node
  val field : map -> node -> fieldinfo -> node
  val shift : map -> node -> typ -> node

  val base_addr : map -> node -> node


  (* API POINTERS *)
  val points_to : map -> node -> node option
  val pointed_by : map -> node -> node list


  (* COMPARATOR *)
  val separated : map -> node -> node -> bool
  val included : map -> node -> node -> bool
  val equal : map -> node -> node -> bool

  (* API ITERATOR *)
  val iter : map -> (node -> unit) -> unit


  (* API PRINTER *)
  val pp_node : Format.formatter -> node -> unit


  (* API ACCESS *)
  type acs = {
    acs_read  : typ list;
    acs_write : typ list;
    acs_shift : typ list;
  }
  val empty_acs : acs
  val accesses : map -> node -> acs
end




(* High level API *)
module Region : sig
  (* General type *)
  type region
  type map

  (* API GETTERS *)
  val get_map : kernel_function -> map

  val get_id : map -> region -> int
  val get_region : map -> int -> region option

  val cvar : map -> varinfo -> region option
  val field : map -> region -> fieldinfo -> region option
  val shift : map -> region -> typ -> region option

  val base_addr : map -> region -> region


  (* API POINTERS *)
  val points_to : map -> region -> region option
  val pointed_by : map -> region -> region list


  (* COMPARATOR *)
  val separated : map -> region -> region -> bool
  val included : map -> region -> region -> bool
  val equal : map -> region -> region -> bool

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
end
