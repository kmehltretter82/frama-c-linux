(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

(** Every access to annotations have to go through here,
  * so this is the place where we decide what the computation
  * is allowed to use. *)

open Cil_types
open WpPropId

(*----------------------------------------------------------------------------*)

(** A proof accumulator for a set of related prop_id *)
type proof

val create_proof : prop_id -> proof
(** to be used only once for one of the related prop_id *)

val add_proof : proof -> prop_id -> Property.t list -> unit
(** accumulate in the proof the partial proof for this prop_id *)

val add_invalid_proof : proof -> unit
(** add an invalid proof result ; can not revert a complete proof *)

val is_composed : proof -> bool
(** whether a proof needs several lemma to be complete *)

val is_proved : proof -> bool
(** whether all partial proofs have been accumulated or not *)

val is_invalid : proof -> bool
(** whether an invalid proof result has been registered or not *)

val target : proof -> Property.t
val dependencies : proof -> Property.t list

val filter_status : prop_id -> bool

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Function Calls                                --- *)
(* -------------------------------------------------------------------------- *)

val get_called_preconditions_at : kernel_function -> stmt -> Property.t list
val get_called_post_conditions : kernel_function -> Property.t list
val get_called_exit_conditions : kernel_function -> Property.t list
val get_called_assigns : kernel_function -> Property.t list

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Behaviors                                     --- *)
(* -------------------------------------------------------------------------- *)

type behavior = {
  bhv_assumes: pred_info list ;
  bhv_requires: pred_info list ;
  bhv_ensures: pred_info list ;
  bhv_exits: pred_info list ;
  bhv_assigns: assigns_full_info ;
}

val get_requires : kernel_function -> kinstr -> funbehavior -> pred_info list
val get_behavior : kernel_function -> kinstr -> active:string list ->
  funbehavior -> behavior

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Assertions                                    --- *)
(* -------------------------------------------------------------------------- *)

type code_assertions = {
  code_admitted: pred_info list ;
  code_verified: pred_info list ;
}

val get_code_assertions : kernel_function -> stmt -> code_assertions

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Loop Contracts                                --- *)
(* -------------------------------------------------------------------------- *)

type loop_contract = {
  (** to be verified at loop entry *)
  loop_established: pred_info list;
  (** to be assumed for loop current *)
  loop_invariants: pred_info list;
  (** to be verified after loop body *)
  loop_preserved: pred_info list;
  (** assigned by loop body *)
  loop_assigns: assigns_full_info list;
}

val get_loop_contract : kernel_function -> stmt -> loop_contract

(* -------------------------------------------------------------------------- *)

(* ########################################################################## *)
(* ###      WARNING:  DEPRECATED API BELOW THIS LINE                      ### *)
(* ########################################################################## *)

(**/**)

type asked_assigns = NoAssigns | OnlyAssigns | WithAssigns

val get_id_prop_strategies :
  model:WpContext.model ->
  ?assigns:asked_assigns -> Property.t -> WpStrategy.strategy list

val get_call_pre_strategies :
  model:WpContext.model ->
  stmt -> WpStrategy.strategy list

val get_function_strategies :
  model:WpContext.model ->
  ?assigns:asked_assigns ->
  ?bhv:string list ->
  ?prop:string list ->
  Kernel_function.t -> WpStrategy.strategy list

(*----------------------------------------------------------------------------*)
