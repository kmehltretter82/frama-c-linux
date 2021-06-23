(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

open Cil_types

(** Every access to annotations have to go through here,
  * so this is the place where we decide what the computation
  * is allowed to use. *)

(* ########################################################################## *)
(* ###      WARNING:  DEPRECATED API                                      ### *)
(* ########################################################################## *)

(*----------------------------------------------------------------------------*)

val unreachable_proved : int ref
val unreachable_failed : int ref
val trivial_terminates : int ref
val set_unreachable : WpPropId.prop_id -> unit
val set_trivially_terminates : WpPropId.prop_id -> unit

type asked_assigns = NoAssigns | OnlyAssigns | WithAssigns

val get_call_pre_strategies :
  model:WpContext.model ->
  stmt -> WpStrategy.strategy list

val get_function_strategies :
  model:WpContext.model ->
  ?assigns:asked_assigns ->
  ?bhv:string list ->
  ?prop:string list ->
  Kernel_function.t -> WpStrategy.strategy list

val get_property_strategies :
  model:WpContext.model -> Property.t -> WpStrategy.strategy list

(*----------------------------------------------------------------------------*)
