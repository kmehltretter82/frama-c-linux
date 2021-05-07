(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(** Analysis for values and pointers *)

module Value_results: sig
  type results

  val get_results: unit -> results
  val set_results: results -> unit
  val merge: results -> results -> results
  val change_callstacks:
    (Value_types.callstack -> Value_types.callstack) -> results -> results
end

module Value_parameters: sig
  (** Returns the list (name, descr) of currently enabled abstract domains. *)
  val enabled_domains: unit -> (string * string) list

  (** [use_builtin kf name] instructs the analysis to use the builtin [name]
      to interpret calls to function [kf].
      Raises [Not_found] if there is no builtin of name [name]. *)
  val use_builtin: Cil_types.kernel_function -> string -> unit

  (** [use_global_value_partitioning vi] instructs the analysis to use
      value partitioning on the global variable [vi]. *)
  val use_global_value_partitioning: Cil_types.varinfo -> unit
end

module Eval_terms: sig
  (** Evaluation environment, built by [env_annot]. *)
  type eval_env

  (** Dependencies needed to evaluate a term or a predicate. *)
  type logic_deps = Locations.Zone.t Cil_datatype.Logic_label.Map.t

  type labels_states = Db.Value.state Cil_datatype.Logic_label.Map.t

  val env_annot :
    ?c_labels:labels_states -> pre:Db.Value.state -> here:Db.Value.state ->
    unit -> eval_env

  (** [predicate_deps env p] computes the logic dependencies needed to evaluate
      [p] in the given evaluation environment [env].
      @return None on either an evaluation error or on unsupported construct. *)
  val predicate_deps: eval_env -> Cil_types.predicate -> logic_deps option
end


module Unit_tests: sig
  (** Runs the unit tests of Eva. *)
  val run: unit -> unit
end

(** Register special annotations to locally guide the partitioning of states
    performed by an Eva analysis. *)
module Eva_annotations: sig

  (** Annotations tweaking the behavior of the -eva-slevel paramter. *)
  type slevel_annotation =
    | SlevelMerge        (** Join all states separated by slevel. *)
    | SlevelDefault      (** Use the limit defined by -eva-slevel. *)
    | SlevelLocal of int (** Use the given limit instead of -eva-slevel. *)
    | SlevelFull         (** Remove the limit of number of separated states. *)

  (** Loop unroll annotations. *)
  type unroll_annotation =
    | UnrollAmount of Cil_types.term (** Unroll the n first iterations. *)
    | UnrollFull (** Unroll amount defined by -eva-default-loop-unroll. *)

  type split_kind = Static | Dynamic

  (** Split/merge annotations for value partitioning.  *)
  type flow_annotation =
    | FlowSplit of Cil_types.term * split_kind
    (** Split states according to a term. *)
    | FlowMerge of Cil_types.term
    (** Merge states separated by a previous split. *)

  val add_slevel_annot : emitter:Emitter.t -> loc:Cil_types.location ->
    Cil_types.stmt -> slevel_annotation -> unit
  val add_unroll_annot : emitter:Emitter.t -> loc:Cil_types.location ->
    Cil_types.stmt -> unroll_annotation -> unit
  val add_flow_annot : emitter:Emitter.t -> loc:Cil_types.location ->
    Cil_types.stmt -> flow_annotation -> unit
  val add_subdivision_annot : emitter:Emitter.t -> loc:Cil_types.location ->
    Cil_types.stmt -> int -> unit
end

(** Analysis builtins for the cvalue domain, more efficient than the analysis
    of the C functions. See {builtins.mli} for more details. *)
module Builtins: sig
  open Cil_types

  exception Invalid_nb_of_args of int
  exception Outside_builtin_possibilities

  type builtin_type = unit -> typ * typ list
  type cacheable = Cacheable | NoCache | NoCacheCallers

  type full_result = {
    c_values: (Cvalue.V.t option * Cvalue.Model.t) list;
    c_clobbered: Base.SetLattice.t;
    c_from: (Function_Froms.froms * Locations.Zone.t) option;
  }

  type call_result =
    | States of Cvalue.Model.t list
    | Result of Cvalue.V.t list
    | Full of full_result

  type builtin = Cvalue.Model.t -> (exp * Cvalue.V.t) list -> call_result

  val register_builtin:
    string -> ?replace:string -> ?typ:builtin_type -> cacheable ->
    builtin -> unit

  val is_builtin: string -> bool
end
