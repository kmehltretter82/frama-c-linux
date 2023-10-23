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

(** External API of the plugin Alias *)

open Cil_types

module LSet = Cil_datatype.LvalStructEq.Set
module G : Graph.Sig.G with type V.t = int

(** NB : do the analysis BEFORE using any of those functions *)

(** [points_to_set_stmt kf s lv] returns the points-to set of lval [lv] before
    [stmt] in function [kf]. *)
val points_to_set_stmt : kernel_function -> stmt -> lval -> LSet.t

(** [points_to_set kf s lv] returns the points-to set of lval [lv] at the end
    of function [kf]. *)
val points_to_set_kf : kernel_function -> lval -> LSet.t

(** [aliases_stmt kf s lv] return the alias set of lval [lv] before [stmt] in
    function [kf]. *)
val aliases_stmt : kernel_function -> stmt -> lval -> LSet.t

(** [aliases_kf kf lv] return the alias set of lval [lv] at the end of function
    [kf]. *)
val aliases_kf : kernel_function -> lval -> LSet.t

(** list of pairs [s, e] where [e] is the set of lval aliased to [v] after
    statement [s] in function [kf]. *)
val fundec_stmts : kernel_function -> lval -> (stmt * LSet.t) list


(** [fold_points_to_set f acc kf s lv] folds [f acc] over all the lvals in the
    points-to set of the given lval [lv] right before stmt [s] in function
    [kf]. *)
val fold_points_to_set:
  ('a -> lval -> 'a) -> 'a -> kernel_function -> stmt -> lval -> 'a

(** [fold_aliases_stmt f acc kf s lv] folds [f acc] over all the aliases of the
    given lval [lv] right before stmt [s] in function [kf]. *)
val fold_aliases_stmt:
  ('a -> lval -> 'a) -> 'a -> kernel_function -> stmt -> lval -> 'a

(** [fold_new_aliases_stmt f acc kf s lv] folds [f acc] over all the aliases of
    the given lval [lv] created by stmt [s] in function [kf]. *)
val fold_new_aliases_stmt:
  ('a -> lval -> 'a) -> 'a -> kernel_function -> stmt -> lval -> 'a

(** [fold_points_to_set_kf f acc kf lv] folds [f acc] over the points-to set of lval
    [lv] at the end of function [kf]. *)
val fold_points_to_set_kf :
  ('a -> lval -> 'a) -> 'a -> kernel_function -> lval -> 'a

(** [fold_aliases_kf f acc kf lv] folds [f acc] over all the aliases of lval
    [lv] at the end of function [kf]. *)
val fold_aliases_kf:
  ('a -> lval -> 'a) -> 'a -> kernel_function -> lval -> 'a

(** [fold_fundec_stmts f acc kf v] folds [f acc s e] on the list of
    pairs [s, e] where [e] is the set of lval aliased to [v] after statement [s]
    in function [kf]. *)
val fold_fundec_stmts:
  ('a -> stmt -> lval -> 'a) -> 'a -> kernel_function -> lval -> 'a

(** [are_aliased kf s lv1 lv2] returns true if and only if the two
    lvals [lv1] and [lv2] are aliased before stmt [s] in function
    [kf]. *)
val are_aliased: kernel_function -> stmt -> lval -> lval -> bool

(** [fold_vertex f acc kf s v] folds [f acc i lv] to all [lv] in [i], where [i] is
    the vertex that represents the equivalence class of [v] before statement [s] in function [kf]. *)
val fold_vertex:
  ('a -> G.V.t -> lval -> 'a) -> 'a  -> kernel_function -> stmt -> lval  -> 'a

(** [fold_vertex_closure f acc kf s v] is the transitive closure of function
    [fold_vertex]. *)
val fold_vertex_closure:
  ('a -> G.V.t -> lval -> 'a) -> 'a  -> kernel_function -> stmt -> lval  -> 'a


(** direct access to the abstract state. See Abstract_state.mli *)

module Abstract_state : sig
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

(** [get_state_before_stmt f s] gets the abstract state computed after
    statement [s] in function [f]. Returns [None] if
    the abstract state is bottom or not computed. *)
val get_state_before_stmt :  kernel_function -> stmt -> Abstract_state.t option


(** [call_function a f Some(res) args] computes the abstract state
    after the instruction res=f(args) where res is a lval. [a] is the
    abstract state before the call. If function [f] returns no value,
    use [call_function a f None args] instead. Returns [None] if
    the abstract state [a] is bottom or not computed. *)
val call_function: Abstract_state.t -> kernel_function -> lval option -> exp list -> Abstract_state.t option


(** [simplify_lval lv] returns a lval where every index of an array is
    replaced by 0, evey pointer arithmetic is simplified to an access
    to an array *)
val simplify_lval: lval -> lval
