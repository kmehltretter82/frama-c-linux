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

(** Transfer functions for the main domain of the Value analysis. *)

type value = Main_values.CVal.t
type origin = value
type location = Main_locations.PLoc.location

include Abstract_domain.Transfer
  with type state := Cvalue.Model.t
   and type value := value
   and type location := location
   and type origin := origin

(** [warn_imprecise_write lval loc v] emits a warning about the assignment of
    value [v] into location [loc] if one of them is overly imprecise. [lval] is
    the assigned lvalue, and [prefix] is an optional prefix to the warning. *)
val warn_imprecise_write:
  ?prefix:string -> Cil_types.lval -> Locations.location -> Cvalue.V.t -> unit

(** [warn_imprecise_offsm_write lval offsm] emits a warning about the assignment
    of offsetmap [offsm] if it contains an overly imprecise value. [lval] is the
    assigned lvalue, and [prefix] is an optional prefix to the warning. *)
val warn_imprecise_offsm_write:
  ?prefix:string -> Cil_types.lval -> Cvalue.V_Offsetmap.t -> unit

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
