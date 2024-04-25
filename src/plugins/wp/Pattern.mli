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

open Logic_typing
open Logic_ptree

(* -------------------------------------------------------------------------- *)
(* --- Pattern Engine                                                     --- *)
(* -------------------------------------------------------------------------- *)

type context
type pattern
type value

(** Creates an empty environment *)
val context : typing_context -> context

(** Parse a pattern and enrich the environement with pattern variables *)
val pa_pattern : context -> lexpr -> pattern

(** Parse value according to the environement *)
val pa_value : context -> lexpr -> value

(** Return a value that equals the pattern *)
val self : pattern -> pattern * value

(** Pattern printer *)
val pp_pattern : Format.formatter -> pattern -> unit

(** Value printer *)
val pp_value : Format.formatter -> value -> unit

(** Matching lookup *)
type lookup = {
  head: bool ;
  goal: bool ;
  hyps: bool ;
  split: bool ;
  pattern: pattern ;
}

(** Matching result *)
type sigma

(** Sigma printer *)
val pp_sigma : Format.formatter -> sigma -> unit

(** Empty results *)
val empty : sigma

(** Matching sequent *)
val psequent : lookup -> sigma -> Conditions.sequent -> sigma option

(** Composing values from matching results *)
val select : sigma -> value -> Tactical.selection

(** Composing a boolean *)
val bool : value -> bool

(** Composing a string *)
val string : value -> string

(** Typechecking *)

type env
val env : unit -> env
val typecheck_value : env -> ?tau:Lang.F.tau -> value -> unit
val typecheck_pattern : env -> ?tau:Lang.F.tau -> pattern -> unit
val typecheck_lookup : env -> lookup -> unit

(* -------------------------------------------------------------------------- *)
