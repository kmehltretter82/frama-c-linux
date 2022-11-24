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
open Cil_types
    
open Abstract_state

type lset = Cil_datatype.Lval.Set.t  (* sets of lvalues *)

(** Performes the may-alias analysis. Do it once before using other functions *)
val compute : unit -> unit

(** Minimal API, as presented during kickoff meeting *)
(* we changed:  type varinfo -> type lval *)

val get_class_before_statement : kernel_function -> stmt ->  lval -> lset
val get_class_after_statement : kernel_function -> stmt ->  lval -> lset

val get_class_fundec: kernel_function -> lval -> lset
val get_class_fundec_stmts: kernel_function -> lval -> (stmt*lset) list

    
(** connection with Abstract_state *)

val concretise : MGU.ecr -> lset


(** other functions required by MERCE *)
  
(* checks that two Lval have the same ECR *)
val is_equivalent :  kernel_function -> stmt -> lval -> lval -> bool

(* give the graph vertex of lval *)
val point_to :  kernel_function -> stmt -> lval -> V.t


(* give the graph vertex of lval and its points-to closure *)
val point_to_closure :  kernel_function -> stmt -> lval  -> G.t
