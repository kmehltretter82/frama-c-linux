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

open Eva_ast_types

module type DepsOf = sig
  type location
  val zone_of_exp : (lval -> location) -> exp -> Locations.Zone.t
  val zone_of_lval : (lval -> location) -> lval -> Locations.Zone.t
  val indirect_zone_of_lval : (lval -> location) -> lval -> Locations.Zone.t
  val deps_of_exp : (lval -> location) -> exp -> Deps.t
  val deps_of_lval : (lval -> location) -> lval -> Deps.t
end

module type DepsOfInput = sig
  type location
  val enumerate_valid_bits : Locations.access -> location -> Locations.Zone.t
end

module MakeDepsOf (Loc : DepsOfInput) : DepsOf with type location =
                                                      Loc.location = struct
  type location = Loc.location

  let rec deps_of_exp find_loc exp =
    let rec process exp = match exp.node with
      | Lval lval ->
        deps_of_lval find_loc lval
      | UnOp (_, e, _) | CastE (_, e) ->
        process e
      | BinOp (_, e1, e2, _) ->
        Deps.join (process e1) (process e2)
      | StartOf lv | AddrOf lv ->
        Deps.data (indirect_zone_of_lval find_loc lv)
      | Const _ ->
        Deps.bottom
    in
    process exp

  and zone_of_exp find_loc exp = Deps.to_zone (deps_of_exp find_loc exp)

  and deps_of_lval find_loc lval =
    let ploc = find_loc lval in
    (* dereference of an lvalue: first, its address must be computed,
       then its contents themselves are read *)
    let indirect = indirect_zone_of_lval find_loc lval in
    let data = Loc.enumerate_valid_bits Read ploc in
    { Deps.data ; indirect }

  and zone_of_lval find_loc lval = Deps.to_zone (deps_of_lval find_loc lval)

  (* Computations of the inputs of a lvalue : union of the "host" part and
     the offset. *)
  and indirect_zone_of_lval find_loc lval =
    let lhost, offset = lval.node in
    let lhost_zone = zone_of_lhost find_loc lhost
    and offset_zone = zone_of_offset find_loc offset in
    Locations.Zone.join lhost_zone offset_zone

  (* Computation of the inputs of a host. Nothing for a variable, and the
     inputs of [e] for a dereference [*e]. *)
  and zone_of_lhost find_loc = function
    | Var _ -> Locations.Zone.bottom
    | Mem e -> zone_of_exp find_loc e

  (* Computation of the inputs of an offset. *)
  and zone_of_offset find_loc = function
    | NoOffset -> Locations.Zone.bottom
    | Field (_, o) -> zone_of_offset find_loc o
    | Index (e, o) ->
      Locations.Zone.join
        (zone_of_exp find_loc e) (zone_of_offset find_loc o)
end

module PreciseDepsOf =
  MakeDepsOf(struct
    include Precise_locs
    type location = Precise_locs.precise_location end)
