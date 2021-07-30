(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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
open Cil_datatype


val compute_guards: location -> is_forall:bool -> predicate -> Logic_var.t list -> predicate -> unit
(** Take a predicate starting with a quantifier and store the scope of its variable *)

val get_preprocessed_quantifier: predicate -> (term * logic_var * term) list * predicate
(** @return the preprocessed of a quantified predicate
    the [(term * logic_var * term) list] is the list of all the quantified variables
    along with their syntactic guards, and the [predicate] is the goal: the original
    predicate with all the quantifiers removed *)

val get_guard_for_small_type : logic_var -> predicate option
(** @return the optional additional guard for a quantified logic variables. It may
    happen that the syntactic guard of the variable can be refined with the type
    of the variable, this additional predicate translates this refinement *)

val clear_guards : unit -> unit
(** Clear the table of guard conditions for quantified variables *)
