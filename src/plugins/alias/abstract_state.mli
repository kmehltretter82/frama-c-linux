(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2023                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)

(** Module abstract_state *)

open Cil_types

open Cil_datatype

(** Points-to graphs datastructure. *)
module G: Graph.Sig.G

module LMap = Lval.Map
module LSet = Lval.Set

(** Type denothing an abstract state of the analysis. It is a graph containing
    all aliases and points-to information. *)
type t

(** check all the invariants that must be true on an abstract value
    before and after each function call or transformation of the graph)  *)
val assert_invariants : t -> unit

(** pretty printer; debug=true prints the graph, debug = false only
    prints aliased variables *)
val pretty : ?debug:bool -> Format.formatter -> t -> unit

(** dot printer *)
val print_dot : string -> t -> unit

(** finds the vertex corresponding to a lval. May raise Not_found *)
val find_vertex : lval -> t -> G.V.t

val find_aliases : lval -> t -> LSet.t

(** Functions for Steensgaard's algorithm *)
val join : t -> G.V.t -> G.V.t -> t

val cjoin : t -> G.V.t -> G.V.t -> t

val set_type : t -> G.V.t -> G.V.t -> t

(** transfert functions for different kinds of assignments *)
val assignment_x_y : t -> lval -> lval -> t

val assignment_x_addr_y : t -> lval -> lval -> t

val assignment_x_ptr_y : t -> lval -> lval -> t

val assignment_x_allocate_y : t -> lval -> lval -> t

val assignment_ptr_x_y : t -> lval -> lval -> t

val assignment_ptr_x_cst : t -> lval -> t

(** equality test *)
val equal : t -> t -> bool

(** union of two abstract values ; ensures that if 2 lval are aliased
    in one of the two input graph (or in a points-to relationship),
    then they will also be aliased/points-to in the result *)
val union : t -> t -> t

(** empty graph *)
val initial_value : t

(** make_top merge all nodes of the graph; the resulting graph has
    only 1 vertex, 1 edge (loop); every lval of the origial graph are
    associated to this vertex *)
val make_top : t -> t

(** Type denoting summaries of functions *)
type summary

val summary_of_state : t -> summary
