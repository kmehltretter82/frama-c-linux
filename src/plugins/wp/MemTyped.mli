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

(* -------------------------------------------------------------------------- *)
(* --- Typed Memory Model                                                 --- *)
(* -------------------------------------------------------------------------- *)

include Sigs.Model

type pointer = NoCast | Fits | Unsafe
val pointer : pointer Context.value


val sizeof : c_object -> term
val last : sigma -> c_object -> loc -> term

val frames : c_object -> loc -> chunk -> frame list

val havoc : c_object -> loc -> length:term -> chunk -> fresh:term -> current:term -> term
val sizeof_havoc : c_object -> loc -> term

val eqmem_forall : c_object -> loc -> chunk -> term -> term -> var list * pred * pred

val load_int : sigma -> c_int -> loc -> term
val load_float : sigma -> c_float -> loc -> term
val load_pointer : sigma -> typ -> loc -> loc

val store_int : sigma -> c_int -> loc -> term -> Chunk.t * term
val store_float : sigma -> c_float -> loc -> term -> Chunk.t * term
val store_pointer : sigma -> typ -> loc -> term -> Chunk.t * term

val set_init_atom : sigma -> c_object -> loc -> term -> chunk * term
val set_init : c_object -> loc -> length:term -> chunk -> current:term -> term
val is_init_atom : sigma -> c_object -> loc -> term
val is_init_range : sigma -> c_object -> loc -> term -> pred

val value_footprint : c_object -> loc -> Sigma.domain
val init_footprint : c_object -> loc -> Sigma.domain
