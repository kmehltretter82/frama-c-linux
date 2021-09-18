(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies           *)
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

(* This file is generated. Do not edit. *)

module Results: sig
  (* Usage sketch :
  
     Eva.Results.(before stmt |> in_callstack cs |> eval_var vi |> as_int)
  
     or, if you prefer
  
     Eva.Results.(as_int (eval_var vi (in_callstack cs (before stmt))))
  *)
  
  type callstack = (Cil_types.kernel_function * Cil_types.kinstr) list
  
  type request
  type evaluation
  type lvaluation
  
  type error = Bottom | Top | DisabledDomain
  type 'a result = ('a,error) Result.t
  
  (* Control point selection *)
  val at_start : request
  val at_end : request
  val at_start_of : Cil_types.kernel_function -> request
  val at_end_of : Cil_types.kernel_function -> request
  val before : Cil_types.stmt -> request
  val after : Cil_types.stmt -> request
  val before_kinstr : Cil_types.kinstr -> request
  val after_kinstr : Cil_types.kinstr -> request
  
  (* Callstack selection *)
  val in_callstack : callstack -> request -> request
  val in_callstacks : callstack list -> request -> request
  val filter_callstack : (callstack -> bool) -> request -> request
  
  (* Working with callstacks *)
  val callstacks : request -> callstack list
  val fold_callstacks : (callstack -> request -> 'a -> 'a) -> 'a -> request -> 'a
  val by_callstack : request -> (callstack * request) list
  
  (* State requests *)
  val equality_class : Cil_types.exp -> request -> Cil_types.exp list result
  val as_cvalue_model : request -> Cvalue.Model.t result
  
  (* Evaluation *)
  val eval_var : Cil_types.varinfo -> request -> evaluation
  val eval_lval : Cil_types.lval -> request -> evaluation
  val eval_exp : Cil_types.exp -> request -> evaluation
  
  val eval_address : Cil_types.lval -> request -> lvaluation
  
  (* Value conversion *)
  val as_int : evaluation -> int result
  val as_integer : evaluation -> Integer.t result
  val as_float : evaluation -> float result
  val as_functions : evaluation -> Cil_types.kernel_function list result (* Ignores non-function values *)
  val as_ival : evaluation -> Ival.t result
  val as_fval : evaluation -> Fval.t result
  val as_cvalue : evaluation -> Cvalue.V.t result
  
  val as_location : lvaluation -> Locations.location result
  val as_zone : lvaluation -> Locations.Zone.t result
  
  (* Evaluation properties *)
  val is_initialized : evaluation -> bool
  val alarms : evaluation -> Alarms.t list
  
  (* Bottomness *)
  val is_bottom : evaluation -> bool
  val is_called : Cil_types.kernel_function -> bool (* called during the analysis, not by the actual program *)
  val is_reachable : Cil_types.stmt -> bool (* reachable by the analysis, not by the actual program *)
  
end

module Value_results: sig
  type results
  
  val get_results: unit -> results
  val set_results: results -> unit
  val merge: results -> results -> results
  val change_callstacks:
    (Value_types.callstack -> Value_types.callstack) -> results -> results
  (** Change the callstacks for the results for which this is meaningful.
      For technical reasons, the top of the callstack must currently
      be preserved. *)
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
  type labels_states = Cvalue.Model.t Cil_datatype.Logic_label.Map.t
  
  (** Evaluation environment. Currently available are function Pre and Post, or
      the environment to evaluate an annotation *)
  type eval_env
  val env_annot :
    ?c_labels:labels_states -> pre:Cvalue.Model.t -> here:Cvalue.Model.t ->
    unit -> eval_env
  (** Dependencies needed to evaluate a term or a predicate *)
  type logic_deps = Locations.Zone.t Cil_datatype.Logic_label.Map.t
  (** [predicate_deps env p] computes the logic dependencies needed to evaluate
      [p] in the given evaluation environment [env].
      @return None on either an evaluation error or on unsupported construct. *)
  val predicate_deps: eval_env -> Cil_types.predicate -> logic_deps option
end

module Unit_tests: sig
  (** Currently tested by this module:
      - semantics of sign values. *)
  
  (** Runs some programmatic tests on Eva. *)
  val run: unit -> unit
end

module Eva_annotations: sig
  (** Register special annotations to locally guide the partitioning of states
      performed by an Eva analysis:
  
      - slevel annotations: "slevel default", "slevel merge" and "slevel i"
      - loop unroll annotations: "loop unroll term"
      - value partitioning annotations: "split term" and "merge term"
      - subdivision annotations: "subdivide i"
  
      Widen hints annotations are still registered in !{widen_hints_ext.ml}. *)
  
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
  
  type split_term =
    | Expression of Cil_types.exp
    | Predicate of Cil_types.predicate
  
  (** Split/merge annotations for value partitioning.  *)
  type flow_annotation =
    | FlowSplit of split_term * split_kind
    (** Split states according to a term. *)
    | FlowMerge of split_term
    (** Merge states separated by a previous split. *)
  
  type allocation_kind = By_stack | Fresh | Fresh_weak | Imprecise
  
  val get_slevel_annot : Cil_types.stmt -> slevel_annotation option
  val get_unroll_annot : Cil_types.stmt -> unroll_annotation list
  val get_flow_annot : Cil_types.stmt -> flow_annotation list
  val get_subdivision_annot : Cil_types.stmt -> int list
  val get_allocation: Cil_types.stmt -> allocation_kind
  
  val add_slevel_annot : emitter:Emitter.t ->
    Cil_types.stmt -> slevel_annotation -> unit
  val add_unroll_annot : emitter:Emitter.t ->
    Cil_types.stmt -> unroll_annotation -> unit
  val add_flow_annot : emitter:Emitter.t ->
    Cil_types.stmt -> flow_annotation -> unit
  val add_subdivision_annot : emitter:Emitter.t ->
    Cil_types.stmt -> int -> unit
end

module Eval: sig
  (** Can the results of a function call be cached with memexec? *)
  type cacheable =
    | Cacheable      (** Functions whose result can be safely cached *)
    | NoCache        (** Functions whose result should not be cached, but for
                         which the caller can still be cached. Typically,
                         functions printing something during the analysis. *)
    | NoCacheCallers (** Functions for which neither the call, neither the
                         callers, can be cached *)
end

module Builtins: sig
  (** Eva analysis builtins for the cvalue domain, more efficient than their
      equivalent in C. *)
  
  open Cil_types
  
  exception Invalid_nb_of_args of int
  exception Outside_builtin_possibilities
  
  (* Signature of a builtin: type of the result, and type of the arguments. *)
  type builtin_type = unit -> typ * typ list
  
  (** Can the results of a builtin be cached? See {eval.mli} for more details.*)
  type cacheable = Eval.cacheable = Cacheable | NoCache | NoCacheCallers
  
  type full_result = {
    c_values: (Cvalue.V.t option * Cvalue.Model.t) list;
    (** A list of results, consisting of:
        - the value returned (ie. what is after the 'return' C keyword)
        - the memory state after the function has been executed. *)
    c_clobbered: Base.SetLattice.t;
    (** An over-approximation of the bases in which addresses of local variables
        might have been written *)
    c_from: (Function_Froms.froms * Locations.Zone.t) option;
    (** If not None, the froms of the function, and its sure outputs;
        i.e. the dependencies of the result and of each zone written to. *)
  }
  
  (** The result of a builtin can be given in different forms. *)
  type call_result =
    | States of Cvalue.Model.t list
    (** A disjunctive list of post-states at the end of the C function.
        Can only be used if the C function does not write the address of local
        variables, does not read other locations than the call arguments, and
        does not write other locations than the result. *)
    | Result of Cvalue.V.t list
    (** A disjunctive list of resulting values. The specification is used to
        compute the post-state, in which the result is replaced by the values
        computed by the builtin. *)
    | Full of full_result
    (** See [full_result] type. *)
  
  (** Type of a cvalue builtin, whose arguments are:
      - the memory state at the beginning of the function call;
      - the list of arguments of the function call. *)
  type builtin = Cvalue.Model.t -> (exp * Cvalue.V.t) list -> call_result
  
  (** [register_builtin name ?replace ?typ cacheable f] registers the function [f]
      as a builtin to be used instead of the C function of name [name].
      If [replace] is provided, the builtin is also used instead of the C function
      of name [replace], unless option -eva-builtin-auto is disabled.
      If [typ] is provided, consistency between the expected [typ] and the type of
      the C function is checked before using the builtin.
      The results of the builtin are cached according to [cacheable]. *)
  val register_builtin:
    string -> ?replace:string -> ?typ:builtin_type -> cacheable -> builtin -> unit
  
  (** Has a builtin been registered with the given name? *)
  val is_builtin: string -> bool
end

