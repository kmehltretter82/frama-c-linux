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


(** External API of the plugin Alias
  
*)


(* modules and predefined types *)

open Cil_types

open Cil_datatype

(** [compute ()] performs the may-alias analysis. It must be done once
   before using other functions *)
val compute : unit -> unit

(** [clear()] clears caches and imperative structures that are used by
   the analysis. All accumulated data will be lost *)
val clear : unit -> unit


(* Minimal API, as presented during kickoff meeting *)
  
(** [get_class_before_statment f s v] gives the set of lval aliased to
   [v] before statement [s] in function [f] *)
val get_class_before_statement : kernel_function -> stmt ->  lval -> Lval.Set.t
  

(** [get_class_after_statment f s v] gives the set of lval aliased to
   [v] after statement [s] in function [f] *)
val get_class_after_statement : kernel_function -> stmt ->  lval -> Lval.Set.t

(** [get_class_fundec f v] gives the set of lval aliased to [v] after
   the return statement in function [f] *)
val get_class_fundec: kernel_function -> lval -> Lval.Set.t

(** [fold_fundec_stmts f_fold acc f v] iters function [f_fold acc s e] on the list of pairs <s,e> where e is
   the set of lval aliased to [v] after statement <s> in function [f]
   *)
val fold_fundec_stmts: ('a -> stmt -> lval -> 'a) -> 'a -> kernel_function -> lval -> 'a


(* other functions required by MERCE *)

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
