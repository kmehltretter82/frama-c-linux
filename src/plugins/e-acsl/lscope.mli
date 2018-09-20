(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

(* Handle the logic scope of a term.
  We define the logic scope of a term [t] to be the set of PURELY logic
  variables that are visible by [t]. *)

type lscope_var =
  | Lvs_let of logic_var * term (* the expression to which the lv is binded *)
  | Lvs_quantif of term (* min *) * logic_var * term (* max *)
  | Lvs_formal of logic_var * logic_info (* the logic definition *)
  | Lvs_global of logic_var * term (* same as Lvs_let *)

type t

val empty: t
(* Create an empty logic scope. *)

val is_empty: t -> bool
(* Check whether the given logic scope is empty. *)

val add: lscope_var -> t -> t
(* Return a new logic scope in which the given [lscope_var] has been added. *)

val get_all: t -> lscope_var list
(* Return the list of [lscope_var] of the given logic scope.
  The first element is the first [lscope_var] that was added to [t], the
  second element is the second [lscope_var] that was added to [t], an so on. *)

val effective_lscope_from_pred_or_term: Misc.pred_or_term -> t -> t
(* We define the EFFECTIVE logic scope of a predicate or term [pot],
  for a given POTENTIAL logical [potential_lscope] scope, to be the set [S] of
  logic variables from [potential_lscope] that appear in [pot].
  [effective_lscope_from_pred_or_term pot potential_lscope] computes [S]. *)