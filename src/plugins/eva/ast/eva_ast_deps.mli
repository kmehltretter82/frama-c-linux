(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(** Dependencies of expressions and lvalues. *)

open Eva_ast_types

(** Dependencies of expressions and lvalues based on type [location]. *)
module type DepsOf = sig
  type location

  val zone_of_exp : (lval -> location) -> exp -> Locations.Zone.t
  (** Given a function computing the location of lvalues, computes the memory
      zone on which the value of an expression depends. *)

  val zone_of_lval : (lval -> location) -> lval -> Locations.Zone.t
  (** Given a function computing the location of lvalues, computes the memory
      zone on which the value of an lvalue depends. *)

  val indirect_zone_of_lval : (lval -> location) -> lval -> Locations.Zone.t
  (** Given a function computing the location of lvalues, computes the memory
      zone on which the offset and the pointer expression (if any) of an
      lvalue depend. *)

  val deps_of_exp : (lval -> location) -> exp -> Deps.t
  (** Given a function computing the location of lvalues, computes the memory
      dependencies of an expression. *)

  val deps_of_lval : (lval -> location) -> lval -> Deps.t
  (** Given a function computing the location of lvalues, computes the memory
      dependencies of an lvalue. *)
end

(** Input for [MakeDepsOf] functor. *)
module type DepsOfInput = sig
  type location
  val enumerate_valid_bits : Locations.access -> location -> Locations.Zone.t
  (** See {!Abstract_location.enumerate_valid_bits} *)
end

(** Make [DepsOf] module based on a given [location]. *)
module MakeDepsOf (Loc : DepsOfInput) : DepsOf with type location = Loc.location

(** Dependencies of expressions and lvalues based on
    [Precise_locs.precise_location]. *)
module PreciseDepsOf : DepsOf with type location = Precise_locs.precise_location
