(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

type mode = ACSL | Safe | Frama_C | Skip | Other of string

type 'a result = Kept | Generated of 'a

type exits = (termination_kind * identified_predicate) list
type requires = identified_predicate list
type terminates = identified_predicate option

type 'a gen = (kernel_function -> spec -> 'a)
type status = Property_status.emitted_status

module type Generator =
sig

  type clause
  type behaviors

  val has_behavior : string -> behaviors -> bool
  val collect_behaviors : spec -> behaviors
  val completes : string list list -> behaviors -> clause list option

  val acsl_default : unit -> clause
  val safe_default : bool -> clause
  val frama_c_default : kernel_function -> clause
  val combine_default : clause list -> clause
  val custom_default : string -> kernel_function -> spec -> clause

  val emit : mode -> kernel_function -> funbehavior -> clause result -> unit
end

val register :
  ?gen_exits:exits gen -> ?status_exits:status ->
  ?gen_assigns:assigns gen -> ?status_assigns:status ->
  ?gen_requires:requires gen -> ?gen_allocates:allocation gen ->
  ?status_allocates:status -> ?gen_terminates:terminates gen ->
  ?status_terminates:status ->
  string -> unit

val populate_funspec : kernel_function -> spec -> bool
