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

(** Main domain of the Value Analysis. *)

module State : Abstract_domain.Leaf
  with type value = Main_values.CVal.t
   and type location = Main_locations.PLoc.location
   and type state = Cvalue.Model.t * Locals_scoping.clobbered_set

val registered: Abstractions.Domain.registered

(** Specific functions for partitioning optimizations.  *)

type prefix
module Subpart : Hashtbl.HashedType
val distinct_subpart :
  State.t -> State.t -> (prefix * Subpart.t * Subpart.t) option
val find_subpart : State.t -> prefix -> Subpart.t option

(** Special getters. *)

module Getters (Dom : Abstract.Domain.External) : sig
  val get_cvalue : (Dom.t -> Cvalue.Model.t) option
  val get_cvalue_or_top : Dom.t -> Cvalue.Model.t
  val get_cvalue_or_bottom : Dom.t Lattice_bounds.or_bottom -> Cvalue.Model.t
end


(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
