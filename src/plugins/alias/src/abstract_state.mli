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

(** Module Abstract_state *)

(** see API.Abstract_state for documentation *)

open Cil_types

module EdgeLabel : sig
  type t = Pointer | Field of fieldinfo

  val compare : t -> t -> int
  val default : t
  val is_pointer : t -> bool
  val is_field : t -> bool
  val pretty : Format.formatter -> t -> unit
end

module G: Graph.Sig.G with type V.t = int and type E.label = EdgeLabel.t

module LSet = Cil_datatype.LvalStructEq.Set
module VarSet = Cil_datatype.Varinfo.Set

type t
type v = G.V.t

val vid : v -> int
val get_graph: t -> G.t
val get_vars : v -> t -> VarSet.t
val get_lval_set : v -> t -> LSet.t
val pretty : ?debug:bool -> Format.formatter -> t -> unit
val print_dot : string -> t -> unit
val find_vertex : lval -> t -> v
val find_vars : lval -> t -> VarSet.t
val find_synonyms : lval -> t -> LSet.t

val find_aliases : lval -> t -> LSet.t
[@@alert deprecated "Use find_synonyms or alias_lvals instead!"]

val alias_vars : lval -> t -> VarSet.t
val alias_lvals : lval -> t -> LSet.t

val find_all_aliases : lval -> t -> LSet.t
[@@alert deprecated "Use alias_lvals instead!"]

val points_to_vars : lval -> t -> VarSet.t
val points_to_lvals : lval -> t -> LSet.t
val alias_sets_vars : t -> VarSet.t list
val alias_sets_lvals : t -> LSet.t list

val points_to_set : lval -> t -> LSet.t
[@@alert deprecated "Use points_to_vars or points_to_lvals instead!"]

val find_transitive_closure : lval -> t -> (v * LSet.t) list
val is_included : t -> t -> bool

(** check all the invariants that must be true on an abstract value
    before and after each function call or transformation of the graph) *)
val assert_invariants : t -> unit

(** Functions for Steensgaard's algorithm, see the paper *)
val join : t -> v -> v -> t

(** transfert functions for different kinds of assignments *)
val assignment : t -> lval -> exp -> t

(** transfert function for malloc calls *)
val assignment_x_allocate_y : t -> lval -> t

(** union of two abstract values ; ensures that if 2 lval are
    aliased in one of the two input graph (or in a points-to
    relationship), then they will also be aliased/points-to in the
    result *)
val union : t -> t -> t

(** empty graph *)
val empty : t

(** Type denoting summaries of functions *)
type summary

(** creates a summary from a state and a function *)
val make_summary : t -> kernel_function -> summary

(** pretty printer *)
val pretty_summary :  ?debug:bool -> Format.formatter -> summary -> unit

(** [call a res args s] computes the abstract state after the
    instruction res=f(args), with f summarized by [s]. [a] is the abstract state before the call *)
val call: t -> lval option -> exp list -> summary -> t
