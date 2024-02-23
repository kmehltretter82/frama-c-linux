(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(** Implementation of domain queries for the cvalue domain. *)
include Abstract_domain.Queries
  with type state = Cvalue.Model.t
   and type context = unit
   and type value = Main_values.CVal.t
   and type location = Main_locations.PLoc.location
   and type origin = Main_values.CVal.t

(** Evaluation engine specific to the cvalue domain. *)
include Evaluation_sig.S with type state := state
                          and type context := unit
                          and type value := value
                          and type loc := location
                          and type origin := origin

(** Evaluates the location of a lvalue in a given cvalue state. *)
val lval_to_loc: state -> Cil_types.lval -> Locations.location
