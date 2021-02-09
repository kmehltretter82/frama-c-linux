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

val get_requires : kernel_function -> kinstr -> funbehavior -> pred_info list

val get_behavior :
  kernel_function ->
  ?ki:kinstr -> ?smoking:bool -> ?exits:bool -> ?active:string list ->
  funbehavior -> behavior

val get_preconditions : goal:bool -> kernel_function -> pred_info list
val get_complete_behaviors : kernel_function -> pred_info list
val get_disjoint_behaviors : kernel_function -> pred_info list

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Assertions                                    --- *)
(* -------------------------------------------------------------------------- *)

type code_assertions = {
  code_admitted: pred_info list ;
  code_verified: pred_info list ;
}

val get_code_assertions :
  ?smoking:bool -> kernel_function -> stmt -> code_assertions

val get_unreachable : kernel_function -> stmt -> WpPropId.prop_id

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Loop Contracts                                --- *)
(* -------------------------------------------------------------------------- *)

type loop_contract = {
  (** to be verified at loop entry *)
  loop_established: WpPropId.pred_info list;
  (** to be assumed for loop current *)
  loop_invariants: WpPropId.pred_info list;
  (** to be proved after loop invariants *)
  loop_smoke: WpPropId.pred_info list;
  (** to be verified after loop body *)
  loop_preserved: WpPropId.pred_info list;
  (** assigned by loop body *)
  loop_assigns: WpPropId.assigns_full_info list;
}

val get_loop_contract : ?smoking:bool ->
  kernel_function -> stmt -> loop_contract

(* -------------------------------------------------------------------------- *)
(* --- Property Accessors : Call Contracts                                --- *)
(* -------------------------------------------------------------------------- *)

type call_contract = {
  call_pre : pred_info list ;
  call_post : pred_info list ;
  call_exit : pred_info list ;
  call_smoke : pred_info list ;
  call_assigns : assigns ;
}

val get_precond_at : kernel_function -> stmt -> pred_info -> pred_info
val get_call_contract : ?smoking:stmt -> kernel_function -> call_contract

(* -------------------------------------------------------------------------- *)
(* --- Clear Tablesnts                                                    --- *)
(* -------------------------------------------------------------------------- *)

val clear : unit -> unit

(* -------------------------------------------------------------------------- *)
