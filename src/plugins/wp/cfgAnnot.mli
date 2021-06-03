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
open WpPropId

(** Normalization of Annotations.

    Labels are renamed wrt NormAtLabels and reorganized for use/prove
    dispatching in [CfgCalculus]. *)

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Behaviors                                     --- *)
(* -------------------------------------------------------------------------- *)

type behavior = {
  bhv_assumes: pred_info list ;
  bhv_requires: pred_info list ;
  bhv_smokes: pred_info list ;
  bhv_ensures: pred_info list ;
  bhv_exits: pred_info list ;
  bhv_post_assigns: assigns_full_info ;
  bhv_exit_assigns: assigns_full_info ;
}

val get_requires :
  goal:bool -> kernel_function -> funbehavior -> pred_info list

val get_preconditions :
  goal:bool -> kernel_function -> pred_info list

val get_behavior_goals :
  kernel_function ->
  ?smoking:bool -> ?exits:bool ->
  funbehavior -> behavior

val get_complete_behaviors : kernel_function -> pred_info list
val get_disjoint_behaviors : kernel_function -> pred_info list

val get_terminates : kernel_function -> pred_info option

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Assertions                                    --- *)
(* -------------------------------------------------------------------------- *)

type code_assertions = {
  code_admitted: pred_info list ;
  code_verified: pred_info list ;
}

val get_code_assertions :
  ?smoking:bool -> kernel_function -> stmt -> code_assertions

val get_unreachable : kernel_function -> stmt -> prop_id
val get_stmt_assigns : kernel_function -> stmt -> assigns_full_info list

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Loop Contracts                                --- *)
(* -------------------------------------------------------------------------- *)

type loop_contract = {
  loop_terminates: predicate option;
  (** to be verified at loop entry *)
  loop_established: pred_info list;
  (** to be assumed for loop current *)
  loop_invariants: pred_info list;
  (** to be proved after loop invariants *)
  loop_smoke: pred_info list;
  (** to be verified after loop body *)
  loop_preserved: pred_info list;
  (** assigned by loop body *)
  loop_assigns: assigns_full_info list;
}

val get_loop_contract : ?smoking:bool -> ?terminates:predicate ->
  kernel_function -> stmt -> loop_contract

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Call Contracts                                --- *)
(* -------------------------------------------------------------------------- *)

type contract = {
  contract_cond : pred_info list ;
  contract_hpre : pred_info list ;
  contract_post : pred_info list ;
  contract_exit : pred_info list ;
  contract_smoke : pred_info list ;
  contract_assigns : assigns ;
  contract_terminates : predicate ;
}

val get_call_contract : ?smoking:stmt -> kernel_function -> stmt -> contract

(* -------------------------------------------------------------------------- *)
(* --- Clear Tablesnts                                                    --- *)
(* -------------------------------------------------------------------------- *)

val clear : unit -> unit

(* -------------------------------------------------------------------------- *)
