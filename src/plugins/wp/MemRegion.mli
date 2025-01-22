(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
open Memory
open Sigma

type prim = | Int of c_int | Float of c_float | Ptr
type kind = Single of prim | Many of prim | Garbled
val pp_kind : Format.formatter -> kind -> unit

(* -------------------------------------------------------------------------- *)
(* --- Region Memory Model                                                --- *)
(* -------------------------------------------------------------------------- *)

module type RegionProxy =
sig
  type region
  val id : region -> int
  val of_id : int -> region option
  val pretty : Format.formatter -> region -> unit
  val kind : region -> kind
  val name : region -> string option
  val cvar : varinfo -> region option
  val field : region -> fieldinfo -> region option
  val shift : region -> c_object -> region option
  val points_to : region -> region option
  val literal : eid:int -> Cstring.cst -> region option
  val separated : region -> region -> bool
  val included : region -> region -> bool
  val footprint : region -> region list
end

module type ModelWithLoader =
sig
  include Memory.Model
  val sizeof : c_object -> term

  val last : sigma -> c_object -> loc -> term
  val frames : c_object -> loc -> chunk -> frame list

  val memcpy : c_object -> mtgt:term -> msrc:term -> ltgt:loc -> lsrc:loc ->
    length:term -> Chunk.t -> term

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

module Make : RegionProxy -> ModelWithLoader -> Memory.Model
