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

(** Points-to graphs datastructure. *)
module G: Graph.Sig.G

(** NB : do the analysis BEFORE using any of those functions *)

(* previously get_class_before_statement *)
(** [fold_aliases_stmt f acc kf s lv] folds [f acc] over all the aliases of the
    given lval [lv] right before stmt [s] in function [kf]. *)
val fold_aliases_stmt:
  ('a -> lval -> 'a) -> 'a -> kernel_function -> stmt -> lval -> 'a

(* previously get_class_after_statment *)
(** [fold_new_aliases_stmt f acc kf s lv] folds [f acc] over all the aliases of
    the given lval [lv] created by stmt [s] in function [kf]. *)
val fold_new_aliases_stmt:
  ('a -> lval -> 'a) -> 'a -> kernel_function -> stmt -> lval -> 'a

(* previously get_class_fundec *)
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

module Abstract_state : Abstract_state.S

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
