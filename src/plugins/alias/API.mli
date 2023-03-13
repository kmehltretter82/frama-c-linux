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

(** External API of the plugin Alias *)

open Cil_types
open Cil_datatype
(* NB : do the analysis BEFORE using any of those functions *)

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

(** [fold_points_to f acc kf s v] folds [f acc setv] where
    [setv] is the set of lvals that are pointed to by [v] before
    statement [s] in function [kf]. *)
val fold_points_to:
  ('a ->  Lval.Set.t -> 'a) -> 'a  -> kernel_function -> stmt -> lval  -> 'a

(** [fold_points_to_closure f acc kf s v] is the transitive closure of function
    [fold_points_to]. *)
val fold_points_to_closure:
  ('a ->  Lval.Set.t -> 'a) -> 'a  -> kernel_function -> stmt -> lval  -> 'a


(** direct access to the abstract state. See Abstract_state.mli *)

module Abstract_state : Abstract_state.S

(** [get_state_before_stmt f s] gets the abstract state computed after
    statement [s] in function [f]. Returns [None] if
    the abstract state is bottom or not computed *)                          
val get_state_before_stmt :  kernel_function -> stmt -> Abstract_state.t option

(** [get_summary f] gets the summary off unction [f]. Returns [None] if
    the summary is bottom or not computed *)
val get_summary :  kernel_function -> Abstract_state.summary option

