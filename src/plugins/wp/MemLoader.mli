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

(* -------------------------------------------------------------------------- *)

(** Compound Loader *)

open Cil_types
open Definitions
open Ctypes
open Lang.F
open Memory
open Sigma

val cluster : unit -> cluster

(** Loader Model for Atomic Values *)
module type Model =
sig

  val name : string

  type loc
  val sizeof : c_object -> term
  val field : loc -> fieldinfo -> loc
  val shift : loc -> c_object -> term -> loc

  (** Conversion among loc, t_pointer terms and t_addr terms *)

  val to_addr : loc -> term
  val to_region_pointer : loc -> int * term
  val of_region_pointer : int -> c_object -> term -> loc

  val value_footprint: c_object -> loc -> domain
  val init_footprint: c_object -> loc -> domain

  val frames : c_object -> loc -> chunk -> frame list

  val last : sigma -> c_object -> loc -> term

  val memcpy : c_object -> mtgt:term -> msrc:term -> ltgt:loc -> lsrc:loc ->
    length:term -> Chunk.t -> term

  val eqmem_forall :
    c_object -> loc -> Chunk.t -> term -> term -> var list * pred * pred

  val load_int : sigma -> c_int -> loc -> term
  val load_float : sigma -> c_float -> loc -> term
  val load_pointer : sigma -> typ -> loc -> loc

  val store_int : sigma -> c_int -> loc -> term -> Chunk.t * term
  val store_float : sigma -> c_float -> loc -> term -> Chunk.t * term
  val store_pointer : sigma -> typ -> loc -> term -> Chunk.t * term

  val is_init_atom : sigma -> c_object -> loc -> term
  val is_init_range : sigma -> c_object -> loc -> term -> pred
  val set_init_atom : sigma -> c_object -> loc -> term -> Chunk.t * term
  val set_init : c_object -> loc -> length:term ->
    Chunk.t -> current:term -> term

end

(** Generates Loader for Compound Values *)
module Make (M : Model) :
sig

  val domain : c_object -> M.loc -> domain

  val load : sigma -> c_object -> M.loc -> M.loc Memory.value
  val load_init : sigma -> c_object -> M.loc -> term
  val load_value : sigma -> c_object -> M.loc -> term

  val memcpy : sigma sequence -> c_object -> ?lsrc:M.loc -> M.loc -> equation list
  val memcpy_length : sigma sequence -> c_object -> ?lsrc:M.loc -> M.loc -> term -> equation list

  val stored : sigma sequence -> c_object -> M.loc -> term -> equation list
  val stored_init : sigma sequence -> c_object -> M.loc -> term -> equation list
  val copied : sigma sequence -> c_object -> M.loc -> M.loc -> equation list
  val copied_init : sigma sequence -> c_object -> M.loc -> M.loc -> equation list

  val assigned : sigma sequence -> c_object -> M.loc sloc -> equation list

  val initialized : sigma -> M.loc rloc -> pred

end

(* -------------------------------------------------------------------------- *)
