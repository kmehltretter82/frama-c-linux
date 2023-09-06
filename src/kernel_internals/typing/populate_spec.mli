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

(** This module is used to generate missing specifications Options
    {!Kernel.GeneratedDefaultSpec}, {!Kernel.GeneratedSpecMode} and
    {!Kernel.GeneratedSpecCustom} can be used to chose in details which clause
    to generate in which cases.
    *)

open Cil_types

(** Different types of clauses which can be generated via
    {!populate_funspec}. *)
type clause = [
  | `Exits
  | `Assigns
  | `Requires
  | `Allocates
  | `Terminates
]

(** Represents exits clause in the sense of
    {!Cil_types.behavior.b_post_cond}. *)
type exits = (termination_kind * identified_predicate) list

(** Assigns clause *)
type assigns = Cil_types.assigns

(** Allocation clause *)
type allocation = Cil_types.allocation

(** Represents requires clause in the sense of
    {!Cil_types.behavior.b_requires}. *)
type requires = identified_predicate list

(** Represents terminates clause in the sense of
    {!Cil_types.spec.spec_terminates}. *)
type terminates = identified_predicate option

(** Type of a function that, given a {!Kernel_function.t} and a
    {!Cil_types.spec}, returns a clause. Accepted clause types includes
    {!exits}, {!assigns}, {!requires}, {!allocation} and {!terminates}. *)
type 'a gen = (kernel_function -> spec -> 'a)

(** Short name for clarity, status emitted for properties. *)
type status = Property_status.emitted_status

(** [register ?gen_exits ?gen_requires ?status_allocates ... name] registers a
    new mode called [name] which can then be used for specification generation
    (see {!Kernel.GeneratedSpecMode} and {!Kernel.GeneratedSpecCustom}). All
    parameters except [name] are optionals, meaning default action will be
    performed if left unspecified (can trigger a warnings).
*)
val register :
  ?gen_exits:exits gen -> ?status_exits:status ->
  ?gen_assigns:assigns gen -> ?status_assigns:status ->
  ?gen_requires:requires gen -> ?gen_allocates:allocation gen ->
  ?status_allocates:status -> ?gen_terminates:terminates gen ->
  ?status_terminates:status ->
  string -> unit

(** [populate_funspec ~do_body ?funspec kf] generates missing
    specifications for the [kf].
    By default ~do_body is false, meaning only specification of prototypes will
    be generated.
    If None, [Annotations.funspec kf] will be used to get kf's funspec.
    *)
val populate_funspec :
  ?do_body:bool -> ?funspec:funspec -> kernel_function -> clause list -> unit
