(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open LogicUsage
open VCS
open Cil_types
open Cil_datatype
open WpPropId

type index =
  | Axiomatic of string option
  | Function of kernel_function * string option

(* ------------------------------------------------------------------------ *)
(**{1 Proof Obligations}                                                    *)
(* ------------------------------------------------------------------------ *)

module DISK :
sig
  val cache_log : pid:prop_id -> model:WpContext.model ->
    prover:prover -> result:result -> string
  val pretty : pid:prop_id -> model:WpContext.model ->
    prover:prover -> result:result -> Format.formatter -> unit
  val file_kf : kf:kernel_function -> model:WpContext.model -> prover:prover -> string
  val file_goal : pid:prop_id -> model:WpContext.model -> prover:prover -> string
  val file_logout : pid:prop_id -> model:WpContext.model -> prover:prover -> string
  val file_logerr : pid:prop_id -> model:WpContext.model -> prover:prover -> string
end

module GOAL :
sig
  type t
  open Lang
  val dummy : t
  val trivial : t
  val is_trivial : t -> bool
  val make : Conditions.sequent -> t
  val compute : pid:WpPropId.prop_id -> t -> unit
  val compute_proof : pid:WpPropId.prop_id -> t -> F.pred
  val compute_descr : pid:WpPropId.prop_id -> t -> Conditions.sequent
  val compute_probes : pid:WpPropId.prop_id -> t -> Conditions.probe list
  val get_descr : t -> Conditions.sequent
  val qed_time : t -> float
end

module VC_Lemma :
sig

  type t = {
    lemma : Definitions.dlemma ;
    depends : logic_lemma list ;
    mutable sequent : Conditions.sequent option ;
  }

  val is_trivial : t -> bool
  val cache_descr : t -> (prover * result) list -> string

end

module VC_Annot :
sig

  type t = {
    axioms : Definitions.axioms option ;
    goal : GOAL.t ;
    tags : Splitter.tag list ;
    warn : Warning.t list ;
    deps : Property.Set.t ;
    path : Stmt.Set.t ;
    source : (stmt * Mcfg.goal_source) option ;
  }

  val is_trivial : t -> bool
  val resolve : pid:prop_id -> t -> bool
  val cache_descr : pid:prop_id -> t -> (prover * result) list -> string

end

(* ------------------------------------------------------------------------ *)
(**{1 Proof Obligations}                                                    *)
(* ------------------------------------------------------------------------ *)

type formula =
  | GoalLemma of VC_Lemma.t
  | GoalAnnot of VC_Annot.t

type po = t and t = {
    po_gid   : string ;  (** goal identifier *)
    po_sid   : string ;  (** goal short identifier (without model) *)
    po_name  : string ;  (** goal informal name *)
    po_idx   : index ;   (** goal index *)
    po_model : WpContext.model ;
    po_pid   : WpPropId.prop_id ; (* goal target property *)
    po_formula : formula ; (* proof obligation *)
  }

module S : Datatype.S_with_collections with type t = po
module Index : Map.OrderedType with type t = index
module Gmap : Map.S with type key = index

(** Dynamically exported
    @since Nitrogen-20111001
*)
val get_gid: t -> string

(** Dynamically exported
    @since Oxygen-20120901
*)
val get_property: t -> Property.t
val get_index : t -> index
val get_label : t -> string
val get_model : t -> WpContext.model
val get_scope : t -> WpContext.scope
val get_context : t -> WpContext.context
val get_file_logout : t -> prover -> string
(** only filename, might not exists *)

val get_file_logerr : t -> prover -> string
(** only filename, might not exists *)

val get_files : t -> (string * string) list

val qed_time : t -> float

val clear : unit -> unit
val remove : t -> unit

val add : t -> unit
val age : t -> int (* generation *)

val reduce : t -> bool
(** tries simplification *)

val resolve : t -> bool
(** tries simplification and set result if valid *)

val set_result : t -> prover -> result -> unit
val clear_results : t -> unit

val add_modified_hook : (t -> unit) -> unit
(** Hook is invoked for each goal results modification.
    Remark: [clear()] does not trigger those hooks,
    Cf. [add_cleared_hook] instead. *)

val add_removed_hook : (t -> unit) -> unit
(** Hook is invoked for each removed goal.
    Remark: [clear()] does not trigger those hooks,
    Cf. [add_cleared_hook] instead. *)

val add_cleared_hook : (unit -> unit) -> unit
(** Register a hook when the entire table is cleared. *)

val compute : t -> Definitions.axioms option * Conditions.sequent

(** Warning: Prover results are stored as they are from prover output,
    without taking into consideration that validity is inverted
    for smoke tests.

    On the contrary, proof validity is computed with respect to
    smoke test/non-smoke test.
*)

(** Definite result for this prover (not computing) *)
val has_verdict : t -> prover -> bool

(** Raw prover result (without any respect to smoke tests) *)
val get_result : t -> prover -> result

(** All raw prover results (without any respect to smoke tests) *)
val get_results : t -> (prover * result) list

(** Consolidated wrt to associated property and smoke test. *)
val get_proof : t -> [`Passed|`Failed|`Unknown] * Property.t

(** Associated property. *)
val get_target : t -> Property.t

val is_trivial : t -> bool
(** Currently trivial sequent (no forced simplification) *)

val is_valid : t -> bool
(** Checks for some prover with valid verdict (no forced simplification) *)

val all_not_valid : t -> bool
(** Checks for all provers to give a non-valid, computed verdict *)

val is_passed : t -> bool
(** valid, or all-not-valid for smoke tests *)

val has_unknown : t -> bool
(** Checks there is some provers with a non-valid verdict *)

val warnings : t -> Warning.t list

val is_tactic : t -> bool
val is_smoke_test : t -> bool

val iter :
  ?ip:Property.t ->
  ?index:index ->
  ?on_axiomatics:(string option -> unit) ->
  ?on_behavior:(kernel_function -> string option -> unit) ->
  ?on_goal:(t -> unit) ->
  unit -> unit

(** Dynamically exported.
    @since Nitrogen-20111001
*)
val iter_on_goals: (t -> unit) -> unit

(** All POs related to a given property.
    Dynamically exported
    @since Oxygen-20120901
*)
val goals_of_property: Property.t -> t list

val bar : string
val kf_context : index -> Description.kf
val pp_index : Format.formatter -> index -> unit
val pp_warnings : Format.formatter -> Warning.t list -> unit
val pp_depend : Format.formatter -> Property.t -> unit
val pp_dependency : Description.kf -> Format.formatter -> Property.t -> unit
val pp_dependencies : Description.kf -> Format.formatter -> Property.t list -> unit
val pp_goal : Format.formatter -> t -> unit
val pp_title : Format.formatter -> t -> unit
val pp_logfile : Format.formatter -> t -> prover -> unit

val pp_axiomatics : Format.formatter -> string option -> unit
val pp_function : Format.formatter -> Kernel_function.t -> string option -> unit
val pp_goal_flow : Format.formatter -> t -> unit

(** Dynamically exported. *)
val prover_of_name : string -> prover option

(* -------------------------------------------------------------------------- *)
(* --- Generators                                                         --- *)
(* -------------------------------------------------------------------------- *)

(** VC Generator interface. *)

class type generator =
  object
    method model : WpContext.model
    (** Generate VCs for the given Property. *)

    method compute_ip : Property.t -> t Bag.t
    (** Generate VCs for call preconditions at the given statement. *)

    method compute_call : stmt -> t Bag.t
    (** Generate VCs for all functions
        matching provided behaviors and property names.
        For `~bhv` and `~prop` optional arguments,
        default and empty list means {i all} properties. *)

    method compute_main :
      ?fct:Wp_parameters.functions ->
      ?bhv:string list ->
      ?prop:string list ->
      unit -> t Bag.t
  end

(* -------------------------------------------------------------------------- *)
