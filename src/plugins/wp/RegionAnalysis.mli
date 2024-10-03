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

module R : API
