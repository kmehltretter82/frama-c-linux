(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2022                                               *)
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

(* previously get_class_before_statement *)
(** [fold_aliases_stmt f_fold acc f s lv] folds [f_fold acc] over all
   the aliases of the given lval [lv] right before the the given stmt
   [s] in the given function [f]. *)                                                   
val fold_aliases_stmt: ('a -> lval -> 'a) -> 'a -> kernel_function -> stmt -> lval -> 'a

(* previously get_class_after_statment *)
(** [fold_new_aliases_stmt f_fold acc f s lv] folds [f_fold acc] over
   all the aliases of the given lval [lv] right after the the given
   stmt [s] in the given function [f]. *)  
val fold_new_aliases_stmt: ('a -> lval -> 'a) -> 'a -> kernel_function -> stmt -> lval -> 'a

(* previously get_class_fundec *)
(** [fold_aliases_kf f_fold acc f lv] folds [f_fold acc] over all the
   aliases of the given lval [lv] at the end of the given function
   [f]. *)
val fold_aliases_kf: ('a -> lval -> 'a) -> 'a -> kernel_function -> lval -> 'a
 
(** [fold_fundec_stmts f_fold acc f v] iters function [f_fold acc s e] on the list of pairs <s,e> where e is
    the set of lval aliased to [v] after statement <s> in function [f]
*)
val fold_fundec_stmts: ('a -> stmt -> lval -> 'a) -> 'a -> kernel_function -> lval -> 'a

(** [is equivalent f s v1 v2] checks that two lval [v1] and [v2] have
    the same ECR before statement [s] in function [f] *)
val is_equivalent :  kernel_function -> stmt -> lval -> lval -> bool

(** [fold_points_to f_fold acc f s v] iters [f_fold acc setv] where
    [setv] is the set such as lval [v] may points to any lval [v'] of
    [setv] before statement [s] in function [f] *)
val fold_points_to :  ('a ->  Lval.Set.t -> 'a) -> 'a  -> kernel_function -> stmt -> lval  -> 'a


(** [fold_points_to_closure f_fold acc f s v] is the transitive
    closure of the previous function [fold_points_to] *)
val fold_points_to_closure :  ('a ->  Lval.Set.t -> 'a) -> 'a  -> kernel_function -> stmt -> lval  -> 'a
