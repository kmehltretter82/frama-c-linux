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

module LSet : sig type t end (* sets of lvalues *)

(** Performes the may-alias analysis. Do it once before using other functions *)
val compute : unit -> unit

(** Minimal API, as presented during kickoff meeting *)
(* we changed:  type varinfo -> type lval *)

val get_class_before_statement : stmt ->  lval -> LSet.t
val get_class_after_statement : stmt ->  lval -> LSet.t

val get_class_fundec: fundec ->lval -> LSet.t
val get_class_fundec_stmts: fundec -> lval -> LSet.t list


(** connection with Abstract_state *)

val concretise : MGU.ecr -> LSet.t
