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

(** Register read and written memory zones to {!Inout_access}. *)

open Eval

module type S = sig
  type location
  type value
  type valuation
  val add_logic_assign :
    Analysis_location.t -> location Eval.logic_assign -> location -> unit
  val add_assign_lval :
    Analysis_location.t -> valuation ->
    Eva_ast.lval -> Eva_ast.exp ->
    unit
  val add_assign_var :
    Analysis_location.t -> valuation ->
    Eva_ast.varinfo -> Eva_ast.exp ->
    unit
  val add_read_exp :
    Analysis_location.t -> valuation ->
    Eva_ast.exp ->
    unit
  val add_call_args :
    Analysis_location.t -> valuation ->
    (location, value) Eval.call ->
    unit
end

module Make (Engine : Engine_sig.S) = struct
  module Location = Engine.Loc
  module Eval = Engine.Eval
  module EvaAstDeps = Eva_ast.MakeDepsOf (Location)

  type location = Location.location
  type value = Engine.Val.t
  type valuation = Eval.Valuation.t

  let compute_zones to_loc (lval : Eva_ast.lval) =
    match lval.node with
    | Var vi, NoOffset ->
      Locations.(zone_of_varinfo vi, Zone.bottom)
    | _ ->
      let loc = to_loc lval in
      let lv_zone = Location.enumerate_valid_bits Write loc in
      let lv_indirect_zone = EvaAstDeps.indirect_zone_of_lval to_loc lval in
      lv_zone, lv_indirect_zone

  let add_logic_assign aloc clause location =
    let written = Location.enumerate_valid_bits Write location in
    Inout_access.register_write aloc written;
    let read =
      match clause with
      | Assigns (_, from_deps) ->
        List.fold_left
          (fun acc from_dep ->
             match from_dep.location with
             | Address _ ->
               acc
             | Location from_loc ->
               let read = Location.enumerate_valid_bits Read from_loc in
               Locations.Zone.join acc read)
          Locations.Zone.bottom
          from_deps
      | _ -> Locations.Zone.bottom
    in
    Inout_access.register_read aloc read

  let find_loc valuation = Eval.Valuation.find_loc_def valuation

  let add_assign_lval aloc valuation lval exp =
    let to_loc = find_loc valuation in
    let written_zone, lv_indirect_zone = compute_zones to_loc lval in
    Inout_access.register_write aloc written_zone;
    let exp_zone = EvaAstDeps.zone_of_exp to_loc exp in
    let read_zone = Locations.Zone.join lv_indirect_zone exp_zone in
    Inout_access.register_read aloc read_zone

  let add_assign_var aloc valuation vi exp =
    let lval = Eva_ast.Build.var vi in
    add_assign_lval aloc valuation lval exp

  let add_read_exp aloc valuation exp =
    let to_loc = find_loc valuation in
    let read_zone = EvaAstDeps.zone_of_exp to_loc exp in
    Inout_access.register_read aloc read_zone

  let add_call_args aloc valuation call =
    (* Register read and written zone for named arguments. *)
    let f { formal; concrete } =
      add_assign_var aloc valuation formal concrete
    in
    List.iter f call.arguments;
    (* Register read zones for the rest of the arguments. *)
    let f (concrete, _) =
      add_read_exp aloc valuation concrete
    in
    List.iter f call.rest

end
