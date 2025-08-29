(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Eval

(* Marks all behaviors of the list as inactive. *)
val process_inactive_behaviors:
  kinstr -> kernel_function -> behavior list -> unit

(* Checks "calls" annotations at the given statement according to the inferred
   list of functions at this point. Reduces the given list to the functions
   referred to by "calls" annotations. *)
val check_calls_annotations:
  stmt -> (kernel_function * 'a) list -> (kernel_function * 'a) list

module type S = sig
  type state

  val create: state -> kernel_function -> Active_behaviors.t
  val create_from_spec: state -> spec -> Active_behaviors.t

  val check_fct_preconditions_for_behaviors:
    kinstr -> kernel_function -> behavior list -> Alarmset.status ->
    state list -> state list

  val check_fct_preconditions:
    kinstr -> kernel_function -> Active_behaviors.t ->
    state -> state list

  val check_fct_postconditions_for_behaviors:
    kernel_function -> behavior list -> Alarmset.status ->
    pre_state:state -> post_states:state list -> result:varinfo option ->
    state list

  val check_fct_postconditions:
    kernel_function -> Active_behaviors.t -> termination_kind ->
    pre_state:state -> post_states:state list -> result:varinfo option ->
    state list

  val evaluate_assumes_of_behavior: state -> behavior -> Alarmset.status

  val interp_annot:
    record:bool ->
    kernel_function -> Active_behaviors.t -> stmt -> code_annotation ->
    initial_state:state -> state list -> state list
end

module type LogicDomain = sig
  type t
  val top: t
  val equal: t -> t -> bool
  val evaluate_predicate:
    t Abstract_domain.logic_environment -> t -> predicate -> Alarmset.status
  val reduce_by_predicate:
    t Abstract_domain.logic_environment -> t -> predicate -> bool -> t or_bottom
  val interpret_acsl_extension:
    acsl_extension -> t Abstract_domain.logic_environment -> t -> t
end

module Make (Domain: LogicDomain) : S with type state = Domain.t

