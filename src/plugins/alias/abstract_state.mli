(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

(** Module abstract_state *)

open Cil_types

(** Points-to graphs datastructure. *)
module G: Graph.Sig.G

(** Set of [lval]s. Differs from Cil_datatype.Lval.Set in that is uses a
    different comparison function ([Cil_datatype.LvalStructEq.compare]). *)
module LSet : sig
  include Set.S with type elt = lval

  val pretty: Format.formatter -> t -> unit
end

(** map of [lval]s. Differs from Cil_datatype.Lval.Met in that is uses a
    different comparison function ([Cil_datatype.LvalStructEq.compare]). *)
module LMap : sig
  include Map.S with type key = lval

  val pretty: (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a t -> unit
end

(** external signature *)
module type S =
sig

  (** Type denothing an abstract state of the analysis. It is a graph containing
      all aliases and points-to information. *)
  type t

  (** access to the points-to graph *)
  val get_graph: t -> G.t

  (** set of lvals stored in a vertex *)
  val get_lval_set : G.V.t -> t -> LSet.t

  (** pretty printer; debug=true prints the graph, debug = false only
      prints aliased variables *)
  val pretty : ?debug:bool -> Format.formatter -> t -> unit

  (** dot printer; first argument is a file name *)
  val print_dot : string -> t -> unit

  (** finds the vertex corresponding to a lval.
      @raise Not_found if such a vertex does not exist
  *)
  val find_vertex : lval -> t -> G.V.t

  (** same as previous function, but return a set of lval. Cannot
      raise an exception but may return an empty set if the lval is not
      in the graph *)
  val find_aliases : lval -> t -> LSet.t

  (** similar to the previous functions, but does not only give the
      equivalence class of lv, but also all lv that are aliases in
      other vertex of the graph *)
  val find_all_aliases : lval -> t -> LSet.t

  (** the set of all lvars to which the given variable may point. *)
  val points_to_set : lval -> t -> LSet.t

  (** find_aliases, then recursively finds other sets of lvals. We
      have the property (if lval [lv] is in abstract state [x]) :
      List.hd (find_transitive_closure lv x) = (find_vertex lv x,
      find_aliases lv x) *)
  val find_transitive_closure : lval -> t -> (G.V.t * LSet.t) list

  (** inclusion test; [is_included a1 a2] tests if, for any lvl
      present in a1 (associated to a vertex v1), that it is also
      present in a2 (associated to a vertex v2) and that
      get_lval_set(succ(v1) is included in get_lval_set(succ(v2)) *)
  val is_included : t -> t -> bool

end


include S

(** check all the invariants that must be true on an abstract value
      before and after each function call or transformation of the graph)  *)
val assert_invariants : t -> unit

(** Functions for Steensgaard's algorithm, see the paper *)
val join : t -> G.V.t -> G.V.t -> t

(** transfert functions for different kinds of assignments *)
val assignment : t -> lval -> exp -> t

(** transfert function for malloc calls *)
val assignment_x_allocate_y : t -> lval -> t


(** inclusion test; [is_included a1 a2] tests if, for any lvl present
    in a1 (associated to a vertex v1), that it is also present in a2
    (associated to a vertex v2) and that set(succ(v1) is included in
    set(succ(v2)) *)
val is_included : t -> t -> bool

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
