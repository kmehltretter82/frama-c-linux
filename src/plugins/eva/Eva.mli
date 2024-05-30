(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(** Eva public API.

    The main modules are:
    - Analysis: run the analysis.
    - Results: access analysis results, especially the values of expressions
      and memory locations of lvalues at each program point.

    The following modules allow configuring the Eva analysis:
    - Parameters: change the configuration of the analysis.
    - Eva_annotations: add local annotations to guide the analysis.
    - Builtins: register ocaml builtins to be used by the cvalue domain
      instead of analysing the body of some C functions.

    Other modules are for internal use only. *)

(* This file is generated. Do not edit. *)

module Analysis: sig
  val compute : unit -> unit
  (** Computes the Eva analysis, if not already computed, using the entry point
      of the current project. You may set it with {!Globals.set_entry_point}.
      @raise Globals.No_such_entry_point if the entry point is incorrect
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)

  val is_computed : unit -> bool
  (** Return [true] iff the Eva analysis has been done.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf>
  *)

  val self : State.t
  (** Internal state of Eva analysis from projects viewpoint. *)

  type computation_state = NotComputed | Computing | Computed | Aborted
  (** Computation state of the analysis. *)

  val current_computation_state : unit -> computation_state
  (** Get the current computation state of the analysis, updated by
      [force_compute] and states updates. *)

  val register_computation_hook: ?on:computation_state ->
    (computation_state -> unit) -> unit
  (** Registers a hook that will be called each time the analysis starts or
      finishes. If [on] is given, the hook will only be called when the
      analysis switches to this specific state. *)

  val emitter: Emitter.t
  (** Emitter used by Eva to emit property statuses. *)

  (** Kind of results for the analysis of a function body. *)
  type results =
    | Complete
    (** The results are complete: they cover all possible call contexts of the
        given function. *)
    | Partial
    (** The results are partial, as the functions has not been analyzed in all
        possible call contexts. This happens for recursive functions that are
        not completely unrolled, or if the analysis has stopped unexpectedly. *)
    | NoResults
    (** No results were saved for the function, due to option -eva-no-results.
        Any request at a statement of this function will lead to a Top result. *)

  (* Analysis status of a function. *)
  type status =
    | Unreachable
    (** The function has not been reached by the analysis. Any request in this
        function will lead to a Bottom result. *)
    | SpecUsed
    (** The function specification has been used to interpret its calls:
        its body has not been analyzed. Any request at a statement of this
        function will lead to a Bottom result. *)
    | Builtin of string
    (** The builtin of the given name has been used to interpret the function:
        its body has not been analyzed. Any request at a statement of this
        function will lead to a Bottom result. *)
    | Analyzed of results
    (** The function body has been analyzed. *)

  (** Returns the analysis status of a given function. *)
  val status: Cil_types.kernel_function -> status

  (** Does the analysis ignores the body of a given function, and uses instead
      its specification or a builtin to interpret it?
      Please use {!Eva.Results.are_available} instead to known whether results
      are available for a given function. *)
  val use_spec_instead_of_definition: Cil_types.kernel_function -> bool

  (** Returns [true] if the user has requested that no results should be recorded
      for the given function. Please use {!Eva.Results.are_available} instead
      to known whether results are available for a given function. *)
  val save_results: Cil_types.kernel_function -> bool
end

module Callstack: sig
  (** A call is identified by the function called and the call statement *)
  type call = Cil_types.kernel_function * Cil_types.stmt

  module Call : Datatype.S with type t = call

  (** Eva callstacks. *)
  type callstack = {
    thread: int;
    (* An identifier of the thread's callstack. *)
    entry_point: Cil_types.kernel_function;
    (** The first function function of the callstack. *)
    stack: call list;
    (** A call stack is a list of calls. The head is the latest call. *)
  }

  include Datatype.S_with_collections with type t = callstack

  (** Prints a callstack without displaying call sites. *)
  val pretty_short : Format.formatter -> t -> unit

  (** Prints a hash of the callstack when '-kernel-msg-key callstack'
      is enabled (prints nothing otherwise). *)
  val pretty_hash : Format.formatter -> t -> unit

  (** [compare_lex] compares callstack lexicographically, slightly slower
      than [compare] but in a more natural order, giving more importance
      to the function at bottom of the callstack - the first functions called. *)
  val compare_lex : t -> t -> int

  (*** {2 Stack manipulation} *)

  (*** Constructor *)
  val init : ?thread:int -> Cil_types.kernel_function -> t

  (** Adds a new call to the top of the callstack. *)
  val push : Cil_types.kernel_function -> Cil_types.stmt -> t -> t

  (** Removes the topmost call from the callstack. *)
  val pop : t -> t option

  val top : t -> (Cil_types.kernel_function * Cil_types.stmt) option
  val top_kf : t -> Cil_types.kernel_function
  val top_callsite : t -> Cil_types.kinstr
  val top_call : t -> Cil_types.kernel_function * Cil_types.kinstr

  (** Returns the function that called the topmost function of the callstack. *)
  val top_caller : t -> Cil_types.kernel_function option

  (** {2 Conversion} *)

  (** Gives the list of kf in the callstack from the entry point to the top of the
      callstack (i.e. reverse order of the call stack). *)
  val to_kf_list : t -> Cil_types.kernel_function list

  (** Gives the list of call statements from the bottom to the top of the
      callstack (i.e. reverse order of the call stack). *)
  val to_stmt_list : t -> Cil_types.stmt list

  (** Gives the list of call from the bottom to the top of the callstack
      (i.e. reverse order of the call stack). *)
  val to_call_list : t -> (Cil_types.kernel_function * Cil_types.kinstr) list
end

module Deps: sig
  (** Memory dependencies of an expression. *)
  type t = {
    data: Locations.Zone.t;
    (** Memory zone directly required to evaluate the given expression. *)
    indirect: Locations.Zone.t;
    (** Memory zone read to compute data addresses. *)
  }

  include Datatype.S with type t := t

  val pretty_precise: Format.formatter -> t -> unit
  val pretty_debug: Format.formatter -> t -> unit

  (* Constructors *)

  val top : t
  val bottom : t
  val data : Locations.Zone.t -> t
  val indirect : Locations.Zone.t -> t

  (* Conversion *)

  val to_zone : t -> Locations.Zone.t

  (* Mutators *)

  val add_data : t -> Locations.Zone.t -> t
  val add_indirect : t -> Locations.Zone.t -> t

  (* Map *)

  val map : (Locations.Zone.t -> Locations.Zone.t) -> t -> t

  (* Lattice operators *)

  val is_included : t -> t -> bool
  val join : t -> t -> t
  val narrow : t -> t -> t
end

module Results: sig
  (** Eva's result API is a new interface to access the results of an analysis,
      once it is completed. It may slightly change in the future.

      The idea behind this API is that requests must be decomposed in several
      steps. For instance, to evaluate an expression :

      1. first, you have to state where you want to evaluate it,
      2. optionally, you may specify in which callstack,
      3. you choose the expression to evaluate,
      4. you require a destination type to evaluate into.

      Usage sketch :

      Eva.Results.(
        before stmt |> in_callstack cs |>
        eval_var vi |> as_int |> default 0)

      or equivalently, if you prefer

      Eva.Results.(
        default O (as_int (eval_var vi (in_callstack cs (before stmt))))
  *)

  (** Are results available for a given function? True if the function body has
      been has been analyzed and the results have been saved.
      False if:
      - the function has not been reached by the analysis: all requests in the
        function will lead to a Bottom error.
      - a specification or a builtin has been used instead of analyzing the
        function body: all requests in the function will lead to a Bottom error.
      - results have not been saved, due to the [-eva-no-results] parameter:
        all requests in the function will lead to a Top error. *)
  val are_available : Cil_types.kernel_function -> bool

  type request

  type value
  type address
  type 'a evaluation

  type error = Bottom | Top | DisabledDomain
  type 'a result = ('a,error) Result.t


  (** Results handling *)

  (** Translates an error to a human readable string. *)
  val string_of_error : error -> string

  (** Pretty printer for errors. *)
  val pretty_error : Format.formatter -> error -> unit

  (** Pretty printer for API's results. *)
  val pretty_result : (Format.formatter -> 'a -> unit) ->
    Format.formatter -> 'a result -> unit

  (** [default d r] extracts the value of [r] if [r] is Ok,
      or use the default value [d] otherwise.
      Equivalent to [Result.value ~default:d r] *)
  val default : 'a -> 'a result -> 'a


  (** Control point selection *)

  (** At the start of the analysis, but after the initialization of globals. *)
  val at_start : request

  (** At the end of the analysis, after the main function has returned. *)
  val at_end : unit -> request

  (** At the start of the given function. *)
  val at_start_of : Cil_types.kernel_function -> request

  (** At the end of the given function.
      @raises Kernel_function.No_statement if the function has no body. *)
  val at_end_of : Cil_types.kernel_function -> request

  (** Just before a statement is executed. *)
  val before : Cil_types.stmt -> request

  (** Just after a statement is executed. *)
  val after : Cil_types.stmt -> request

  (** Just before a statement or at the start of the analysis. *)
  val before_kinstr : Cil_types.kinstr -> request

  (** Evaluation in a given cvalue state. Callstacks selection are silently
      ignored on such requests. For internal use, could be modified or removed
      in a future version. *)
  val in_cvalue_state : Cvalue.Model.t -> request


  (** Callstack selection *)

  (** Only consider the given callstack.
      Replaces previous calls to [in_callstack] or [in_callstacks]. *)
  val in_callstack : Callstack.t -> request -> request

  (** Only consider the callstacks from the given list.
      Replaces previous calls to [in_callstack] or [in_callstacks]. *)
  val in_callstacks : Callstack.t list -> request -> request

  (** Only consider callstacks satisfying the given predicate. Several filters
      can be added. If callstacks are also selected with [in_callstack] or
      [in_callstacks], only the selected callstacks will be filtered. *)
  val filter_callstack : (Callstack.t -> bool) -> request -> request


  (** Working with callstacks *)

  (** Returns the list of reachable callstacks from the given request.
      An empty list is returned if the request control point has not been
      reached by the analysis, or if no information has been saved at this point
      (for instance with the -eva-no-results option).
      Use [is_empty request] to distinguish these two cases. *)
  val callstacks : request -> Callstack.t list

  (** Returns a list of subrequests for each reachable callstack from
      the given request. *)
  val by_callstack : request -> (Callstack.t * request) list


  (** State requests *)

  (** Returns the list of expressions which have been inferred to be equal to
      the given expression by the Equality domain. *)
  val equality_class : Cil_types.exp -> request -> Cil_types.exp list result

  (** Returns the Cvalue state. Error cases are converted into the bottom or top
      cvalue state accordingly. *)
  val get_cvalue_model : request -> Cvalue.Model.t

  (** Returns the Cvalue model. *)
  val get_cvalue_model_result : request -> Cvalue.Model.t result

  (** Returns a textual representation of the internal domain states for the given
      request. If [filter] is provided, states are filtered on the given bases
      (for domains that support this feature).
      Returns a list of pair (name, state) for all available domains. *)
  val print_states : ?filter:Base.Hptset.t -> request -> (string * string) list

  (** Dependencies *)

  (** Computes (an overapproximation of) the memory zones that must be read to
      evaluate the given expression, including all adresses computations. *)
  val expr_deps : Cil_types.exp -> request -> Locations.Zone.t

  (** Computes (an overapproximation of) the memory zones that must be read to
      evaluate the given lvalue, including the lvalue zone itself. *)
  val lval_deps : Cil_types.lval -> request -> Locations.Zone.t

  (** Computes (an overapproximation of) the memory zones that must be read to
      evaluate the given lvalue, excluding the lvalue zone itself. *)
  val address_deps : Cil_types.lval -> request -> Locations.Zone.t

  (** Taint of a memory zone, according to the taint domain. *)
  type taint =
    | Direct
    (** Direct data dependency from values provided by the attacker to the given
        memory zone, meaning that the attacker may be able to alter its value. *)
    | Indirect
    (** Indirect dependency from values provided by the attacker to the given
        memory zone. The attacker cannot directly alter this memory, but he may
        be able to impact on the path by which its value is computed. *)
    | Untainted
    (** No taint: the given memory zone cannot be modified by the attacker. *)

  (** Evaluates the taint of a given memory zone, according to the taint domain.
      Returns an error if the taint domain was not enabled. *)
  val is_tainted : Locations.Zone.t -> request -> (taint, error) Result.t

  (** Computes (an overapproximation of) the memory dependencies of an
      expression. *)
  val expr_dependencies : Cil_types.exp -> request -> Deps.t

  (** Evaluation *)

  (** Returns (an overapproximation of) the possible values of the variable. *)
  val eval_var : Cil_types.varinfo -> request -> value evaluation

  (** Returns (an overapproximation of) the possible values of the lvalue. *)
  val eval_lval : Cil_types.lval -> request -> value evaluation

  (** Returns (an overapproximation of) the possible values of the expression. *)
  val eval_exp : Cil_types.exp -> request -> value evaluation


  (** Returns (an overapproximation of) the possible addresses of the lvalue. *)
  val eval_address : ?for_writing:bool ->
    Cil_types.lval -> request -> address evaluation


  (** Returns the kernel functions into which the given expression may evaluate.
      If the callee expression doesn't always evaluate to a function, those
      spurious values are ignored. If it always evaluate to a non-function value
      then the returned list is empty.
      Raises [Stdlib.Invalid_argument] if the callee expression is not an lvalue
      without offset.
      Also see [callee] for a function which applies directly on Call
      statements. *)
  val eval_callee : Cil_types.exp -> request -> Kernel_function.t list result


  (** Evaluated values conversion *)

  (** In all functions below, if the abstract value inferred by Eva does not fit
      in the required type, [Error Top] is returned, as Top is the only possible
      over-approximation of the request. *)

  (** Converts the value into a singleton ocaml int. *)
  val as_int : value evaluation -> int result

  (** Converts the value into a singleton unbounded integer. *)
  val as_integer : value evaluation -> Integer.t result

  (** Converts the value into a floating point number. *)
  val as_float : value evaluation -> float result

  (** Converts the value into a C number abstraction. *)
  val as_ival : value evaluation -> Ival.t result

  (** Converts the value into a floating point abstraction. *)
  val as_fval : value evaluation -> Fval.t result

  (** Converts the value into a Cvalue abstraction. Converts error cases
      into bottom and top values accordingly. *)
  val as_cvalue : value evaluation -> Cvalue.V.t

  (** Converts the value into a Cvalue abstraction. *)
  val as_cvalue_result : value evaluation -> Cvalue.V.t result

  (** Converts the value into a Cvalue abstraction with 'undefined' and 'escaping
      addresses' flags. *)
  val as_cvalue_or_uninitialized : value evaluation -> Cvalue.V_Or_Uninitialized.t


  (** Converts into a C location abstraction. Error cases are converted into
      bottom or top locations accordingly. *)
  val as_location : address evaluation -> Locations.location

  (** Converts into a C location abstraction. *)
  val as_location_result : address evaluation -> Locations.location result

  (** Converts into a Zone. Error cases are converted into bottom or top zones
      accordingly. *)
  val as_zone : address evaluation -> Locations.Zone.t

  (** Converts into a Zone result. *)
  val as_zone_result : address evaluation -> Locations.Zone.t result

  (** Converts into a C location abstraction. Error cases are converted into
      bottom or top locations accordingly. *)
  val as_precise_loc : address evaluation -> Precise_locs.precise_location

  (** Converts into a C location abstraction. *)
  val as_precise_loc_result :
    address evaluation -> Precise_locs.precise_location result


  (** Evaluation properties *)


  (** Does the evaluated abstraction represents only one possible C value or
      memory location? *)
  val is_singleton : 'a evaluation -> bool

  (** Returns whether the evaluated value is initialized or not. If the value have
      been evaluated from a Cil expression, it is always initialized. *)
  val is_initialized : value evaluation -> bool

  (** Returns the set of alarms emitted during the evaluation. *)
  val alarms : 'a evaluation -> Alarms.t list


  (** Reachability *)

  (** Returns true if there are no reachable states for the given request. *)
  val is_empty : request -> bool

  (** Returns true if an evaluation leads to bottom, i.e. if the given expression
      or lvalue cannot be evaluated to a valid result for the given request. *)
  val is_bottom : 'a evaluation -> bool

  (** Returns true if the function has been analyzed. *)
  val is_called : Cil_types.kernel_function -> bool

  (** Returns true if the statement has been reached by the analysis. *)
  val is_reachable : Cil_types.stmt -> bool

  (** Returns true if the statement has been reached by the analysis, or if
      the main function has been analyzed for [Kglobal]. *)
  val is_reachable_kinstr : Cil_types.kinstr -> bool

  val condition_truth_value : Cil_types.stmt -> bool * bool
  (** Provided [stmt] is an 'if' construct, [fst (condition_truth_value stmt)]
      (resp. snd) is true if and only if the condition of the 'if' has been
      evaluated to true (resp. false) at least once during the analysis. *)

  (*** Callers / Callees / Callsites *)

  (** Returns the list of inferred callers of the given function. *)
  val callers : Cil_types.kernel_function -> Cil_types.kernel_function list

  (** Returns the list of inferred callers, and for each of them, the list
      of callsites (the call statements) inside. *)
  val callsites : Cil_types.kernel_function ->
    (Cil_types.kernel_function * Cil_types.stmt list) list


  (** Returns the kernel functions called in the given statement.
      If the callee expression doesn't always evaluate to a function, those
      spurious values are ignored. If it always evaluate to a non-function value
      then the returned list is empty.
      Raises [Stdlib.Invalid_argument] if the statement is not a [Call]
      instruction or a [Local_init] with [ConsInit] initializer. *)
  val callee : Cil_types.stmt -> Kernel_function.t list
end

module Parameters: sig
  (** Configuration of the analysis. *)

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

module Eva_annotations: sig
  (** Register special annotations to locally guide the Eva analysis:

      - slevel annotations: "slevel default", "slevel merge" and "slevel i"
      - loop unroll annotations: "loop unroll term"
      - value partitioning annotations: "split term" and "merge term"
      - subdivision annotations: "subdivide i"
  *)

  (** Annotations tweaking the behavior of the -eva-slevel parameter. *)
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

  type array_segmentation =
    Cil_types.varinfo * Cil_types.offset * Cil_types.exp list

  type domain_scope =
    string (* domain *) *
    Cil_types.varinfo list (* variables that must be tracked by the domain *)

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
  val add_array_segmentation : emitter:Emitter.t ->
    Cil_types.stmt -> array_segmentation -> unit
  val add_domain_scope : emitter:Emitter.t ->
    Cil_types.stmt -> domain_scope -> unit
end

module Eval: sig
  (** Can the results of a function call be cached with memexec? *)
  type cacheable =
    | Cacheable      (** Functions whose result can be safely cached. *)
    | NoCache        (** Functions whose result should not be cached, but for
                         which the caller can still be cached. Typically,
                         functions printing something during the analysis. *)
    | NoCacheCallers (** Functions for which neither the call, neither the
                         callers, can be cached. *)
end

module Assigns: sig
  module DepsOrUnassigned : sig

    type t =
      | DepsBottom (** Bottom of the lattice, never bound inside a memory state
                       at a valid location. (May appear for bases for which the
                       validity does not start at 0, currently only NULL.) *)
      | Unassigned (** Location has never been assigned *)
      | AssignedFrom of Deps.t (** Location guaranteed to have been overwritten,
                                   its contents depend on the [Deps.t] value *)
      | MaybeAssignedFrom of Deps.t  (** Location may or may not have been
                                         overwritten *)

    (** The lattice is [DepsBottom <= Unassigned], [DepsBottom <= AssignedFrom z],
        [Unassigned <= MaybeAssignedFrom] and
        [AssignedFrom z <= MaybeAssignedFrom z]. *)

    val top : t
    val equal : t -> t -> bool
    val may_be_unassigned : t -> bool
    val to_zone : t -> Locations.Zone.t
  end

  module Memory : sig
    include Lmap_bitwise.Location_map_bitwise with type v = DepsOrUnassigned.t

    val find : t -> Locations.Zone.t -> Locations.Zone.t
    (** Imprecise version of find, in which data and indirect dependencies are
        not distinguished *)

    val find_precise : t -> Locations.Zone.t -> Deps.t
    (** Precise version of find *)

    val find_precise_loffset : LOffset.t -> Base.t -> Int_Intervals.t -> Deps.t

    val add_binding : exact:bool -> t -> Locations.Zone.t -> Deps.t -> t
    val add_binding_loc : exact:bool -> t -> Locations.location -> Deps.t -> t
    val add_binding_precise_loc :
      exact:bool -> Locations.access -> t ->
      Precise_locs.precise_location -> Deps.t -> t
  end

  type t = {
    return : Deps.t
  (** Dependencies for the returned value *);
    memory : Memory.t
  (** Dependencies on all the zones modified by the function *);
  }

  include Datatype.S with type t := t

  val top : t
  val join : t -> t -> t
end

module Builtins: sig
  (** Eva analysis builtins for the cvalue domain, more efficient than their
      equivalent in C. *)

  open Cil_types

  exception Invalid_nb_of_args of int
  exception Outside_builtin_possibilities

  (* Signature of a builtin: type of the result, and type of the arguments. *)
  type builtin_type = unit -> typ * typ list

  (** Can the results of a builtin be cached? See {!Eval} for more details.*)
  type cacheable = Eval.cacheable = Cacheable | NoCache | NoCacheCallers

  type full_result = {
    c_values: (Cvalue.V.t option * Cvalue.Model.t) list;
    (** A list of results, consisting of:
        - the value returned (ie. what is after the 'return' C keyword)
        - the memory state after the function has been executed. *)
    c_clobbered: Base.SetLattice.t;
    (** An over-approximation of the bases in which addresses of local variables
        might have been written *)
    c_assigns: (Assigns.t * Locations.Zone.t) option;
    (** If not None:
        - the assigns of the function, i.e. the dependencies of the result
          and of each zone written to.
        - and its sure outputs, i.e. an under-approximation of written zones. *)
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

module Cvalue_callbacks: sig
  (** Register actions to performed during the Eva analysis,
      with access to the states of the cvalue domain.
      This API is for internal use only, and may be modified or removed
      in a future version. Please contact us if you need to register callbacks
      to be executed during an Eva analysis. *)

  type state = Cvalue.Model.t

  (** If not None:
      - the assigns of the function, i.e. the dependencies of the result
        and the dependencies of each zone written to;
      - and its sure outputs, i.e. an under-approximation of written zones. *)
  type call_assigns = (Assigns.t * Locations.Zone.t) option

  type analysis_kind =
    [ `Builtin (** A cvalue builtin is used to interpret the function. *)
    | `Spec  (** The specification is used to interpret the function. *)
    | `Body  (** The function body is analyzed. This is the standard case. *)
    | `Reuse (** The results of a previous analysis of the function are reused. *)
    ]

  (** Signature of a hook to be called before the analysis of each function call.
      Arguments are the callstack of the call, the function called, the initial
      cvalue state, and the kind of analysis performed by Eva for this call. *)
  type call_hook =
    Callstack.t -> Cil_types.kernel_function -> state -> analysis_kind -> unit

  (** Registers a function to be applied at the start of the analysis of each
      function call. *)
  val register_call_hook: call_hook -> unit


  type state_by_stmt = (state Cil_datatype.Stmt.Hashtbl.t) Lazy.t
  type results = { before_stmts: state_by_stmt; after_stmts: state_by_stmt }

  (** Results of a function call. *)
  type call_results =
    [ `Builtin of state list * call_assigns
    (** List of cvalue states at the end of the builtin. *)
    | `Spec of state list
    (** List of cvalue states at the end of the call. *)
    | `Body of results * int
    (** Cvalue states before and after each statement of the given function,
        plus a unique integer id for the call. *)
    | `Reuse of int
      (** The results are the same as a previous call with the given integer id,
          previously recorded with the [`Body] constructor. *)
    ]

  (** Signature of a hook to be called after the analysis of each function call.
      Arguments are the callstack of the call, the function called, the initial
      cvalue state at the start of the call, and the results from its analysis. *)
  type call_results_hook =
    Callstack.t -> Cil_types.kernel_function -> state -> call_results -> unit

  (** Registers a function to be applied at the end of the analysis of each
      function call. *)
  val register_call_results_hook: call_results_hook -> unit
end

module Logic_inout: sig
  (** Functions used by the Inout and From plugins to interpret predicate
      and assigns clauses. This API may change according to these plugins
      development. *)

  (** [predicate_deps ~pre ~here p] computes the logic dependencies needed
      to evaluate the predicate [p] in cvalue state [here], in a function
      whose pre-state is [pre].
      Returns None on either an evaluation error or on unsupported construct. *)
  val predicate_deps:
    pre:Cvalue.Model.t -> here:Cvalue.Model.t ->
    Cil_types.predicate -> Locations.Zone.t option

  (** Returns the list of behaviors of the given function that are active for
      the given initial state. *)
  val valid_behaviors:
    Cil_types.kernel_function -> Cvalue.Model.t -> Cil_types.behavior list

  (** Evaluation of the memory zone read by the \from part of an assigns clause,
      in the given cvalue state.  *)
  val assigns_inputs_to_zone:
    Cvalue.Model.t -> Cil_types.assigns -> Locations.Zone.t

  (** Evaluation of the memory zone written by an assigns clauses, in the given
      cvalue state. *)
  val assigns_outputs_to_zone:
    result: Cil_types.varinfo option ->
    Cvalue.Model.t -> Cil_types.assigns -> Locations.Zone.t

  (** Zones of an lvalue term of an assigns clause. *)
  type tlval_zones = {
    under: Locations.Zone.t; (** Under-approximation of the memory zone. *)
    over: Locations.Zone.t;  (** Over-approximation of the memory zone. *)
    deps: Locations.Zone.t;  (** Dependencies needed to evaluate the address. *)
  }

  (** Evaluation of the memory zones and dependencies of an lvalue term from an
      assigns clause, in the given cvalue state for a read or write access. *)
  val assigns_tlval_to_zones:
    Cvalue.Model.t -> Locations.access -> Cil_types.term -> tlval_zones option

  (** Evaluate the assigns clauses of the given function in its given pre-state,
      and compare them with the dependencies computed by the from plugin.
      Emits warnings if needed, and sets statuses to the assigns clauses. *)
  val verify_assigns:
    Cil_types.kernel_function -> pre:Cvalue.Model.t -> Assigns.t -> unit


  (** [accept_base ~formals ~locals kf b] returns [true] if and only if [b] is:
      - a global
      - a formal or local of one of the callers of [kf]
      - a formal or local of [kf] and the corresponding argument is [true]. *)
  val accept_base:
    formals:bool -> locals:bool -> Kernel_function.t -> Base.t -> bool
end

module Eva_results: sig
  (** Internal temporary API: please do not use it, as it should be removed in a
      future version. *)

  (** {2 Initial cvalue state} *)

  (** Specifies the initial cvalue state to use. *)
  val set_initial_state: Cvalue.Model.t -> unit

  (** Ignores previous calls to [set_initial_state] above, and uses the default
      initial state instead. *)
  val use_default_initial_state: unit -> unit

  (** Specifies the values of the main function arguments. Beware that the
      analysis fails if the number of given values is different from the number
      of arguments of the entry point of the analysis. *)
  val set_main_args: Cvalue.V.t list -> unit

  (** Ignores previous calls to [set_main_args] above, and uses the default
      main argument values instead. *)
  val use_default_main_args: unit -> unit

  (** {2 Results} *)

  type results

  val get_results: unit -> results
  val set_results: results -> unit
  val merge: results -> results -> results

  (** Change the callstacks for the results for which this is meaningful.
      For technical reasons, the top of the callstack must currently
      be preserved. *)
  val change_callstacks:
    (Callstack.t -> Callstack.t) -> results -> results

  val eval_tlval_as_location :
    ?result:Cil_types.varinfo ->
    Cvalue.Model.t ->  Cil_types.term -> Locations.location
end

module Unit_tests: sig
  (** Currently tested by this module:
      - semantics of sign values. *)

  (** Runs some programmatic tests on Eva. *)
  val run: unit -> unit
end
