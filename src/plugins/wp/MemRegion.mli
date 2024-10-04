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
open Sigs

type primitive = | Int of c_int | Float of c_float | Ptr
type kind = Single of primitive | Many of primitive | Garbled
val pp_kind : Format.formatter -> kind -> unit

(* -------------------------------------------------------------------------- *)
(* --- Region Memory Model                                                --- *)
(* -------------------------------------------------------------------------- *)

module type RegionProxy =
sig
  type region
  val null : unit -> region

  val hash : region -> int
  val equal : region -> region -> bool
  val compare : region -> region -> int
  val pretty : Format.formatter -> region -> unit

  val kind : region -> kind

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

module type ModelWithLoader =
sig
  include Sigs.Model

  val sizeof : c_object -> term
  val last : sigma -> c_object -> loc -> term

  val frames : c_object -> loc -> chunk -> frame list

  val havoc : c_object -> loc -> length:term -> chunk -> fresh:term -> current:term -> term

  val eqmem_forall : c_object -> loc -> chunk -> term -> term -> var list * pred * pred

  val load_int : sigma -> c_int -> loc -> term
  val load_float : sigma -> c_float -> loc -> term
  val load_pointer : sigma -> typ -> loc -> loc

  val store_int : sigma -> c_int -> loc -> term -> chunk * term
  val store_float : sigma -> c_float -> loc -> term -> chunk * term
  val store_pointer : sigma -> typ -> loc -> term -> chunk * term

  val set_init_atom : sigma -> c_object -> loc -> term -> chunk * term
  val set_init : c_object -> loc -> length:term -> chunk -> current:term -> term
  val is_init_atom : sigma -> c_object -> loc -> term
  val is_init_range : sigma -> c_object -> loc -> term -> pred

  val value_footprint : c_object -> loc -> domain
  val init_footprint : c_object -> loc -> domain
end

module Make : RegionProxy -> ModelWithLoader -> Sigs.Model
