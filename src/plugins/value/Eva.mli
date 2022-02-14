(** Eva public API.

   The main modules are:
   - Analysis: run the analysis.
   - Results: access analysis results, especially the values of expressions
      and memory locations of lvalues at each program point.

   The following modules allow configuring the Eva analysis:
   - Value_parameters: change the configuration of the analysis.
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
      @raise Db.Value.Incorrect_number_of_arguments if some arguments are
      specified for the entry point using {!Db.Value.fun_set_args}, and
      an incorrect number of them is given.
      @plugin development guide *)

  val is_computed : unit -> bool
  (** Return [true] iff the Eva analysis has been done. *)

  val self : State.t
  (** Internal state of Eva analysis from projects viewpoint. *)
end

module Results: sig
  (** Eva's result API is a work-in-progress interface to allow accessing the
      analysis results once its completed. It is experimental and is very likely
      to change in the future. It aims at replacing [Db.Value] but does not
      completely covers all its usages yet. As for now, this interface has some
      advantages over Db's :

      - evaluations uses every available domains and not only Cvalue;
      - the caller may distinguish failure cases when a request is unsucessful;
      - working with callstacks is easy;
      - some common shortcuts are provided (e.g. for extracting ival directly);
      - overall, individual functions are simpler.

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


  type callstack = (Cil_types.kernel_function * Cil_types.kinstr) list

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


  (** Callstack selection *)

  (** Only consider the given callstack.
      Replaces previous calls to [in_callstack] or [in_callstacks]. *)
  val in_callstack : callstack -> request -> request

  (** Only consider the callstacks from the given list.
      Replaces previous calls to [in_callstack] or [in_callstacks]. *)
  val in_callstacks : callstack list -> request -> request

  (** Only consider callstacks satisfying the given predicate. Several filters
      can be added. If callstacks are also selected with [in_callstack] or
      [in_callstacks], only the selected callstacks will be filtered. *)
  val filter_callstack : (callstack -> bool) -> request -> request


  (** Working with callstacks *)

  (** Returns the list of reachable callstacks from the given request.
      An empty list is returned if the request control point has not been
      reached by the analysis, or if no information has been saved at this point
      (for instance with the -eva-no-results option).
      Use [is_empty request] to distinguish these two cases. *)
  val callstacks : request -> callstack list

  (** Returns a list of subrequests for each reachable callstack from
      the given request. *)
  val by_callstack : request -> (callstack * request) list

  (** Iterates on the reachable callstacks from the request. *)
  val iter_callstacks : (callstack -> request -> unit) -> request -> unit

  (** Folds on the reachable callstacks from the request. *)
  val fold_callstacks : (callstack -> request -> 'a -> 'a) -> 'a -> request -> 'a


  (** State requests *)

  (** Returns the list of expressions which have been inferred to be equal to
      the given expression by the Equality domain. *)
  val equality_class : Cil_types.exp -> request -> Cil_types.exp list result

  (** Returns the Cvalue model. *)
  val as_cvalue_model : request -> Cvalue.Model.t result


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


  (** Evaluation *)

  (** Returns (an overapproximation of) the possible values of the variable. *)
  val eval_var : Cil_types.varinfo -> request -> value evaluation

  (** Returns (an overapproximation of) the possible values of the lvalue. *)
  val eval_lval : Cil_types.lval -> request -> value evaluation

  (** Returns (an overapproximation of) the possible values of the expression. *)
  val eval_exp : Cil_types.exp -> request -> value evaluation


  (** Returns (an overapproximation of) the possible addresses of the lvalue. *)
  val eval_address : Cil_types.lval -> request -> address evaluation


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

  (** Converts the value into a Cvalue abstraction. *)
  val as_cvalue : value evaluation -> Cvalue.V.t result


  (** Converts into a C location abstraction. *)
  val as_location : address evaluation -> Locations.location result

  (** Converts into a Zone. Error cases are converted into bottom or top zones
      accordingly. *)
  val as_zone: ?access:Locations.access -> address evaluation ->
    Locations.Zone.t

  (** Converts into a Zone result. *)
  val as_zone_result : ?access:Locations.access -> address evaluation ->
    Locations.Zone.t result


  (** Evaluation properties *)

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

module Value_parameters: sig
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
    | Cacheable      (** Functions whose result can be safely cached. *)
    | NoCache        (** Functions whose result should not be cached, but for
                         which the caller can still be cached. Typically,
                         functions printing something during the analysis. *)
    | NoCacheCallers (** Functions for which neither the call, neither the
                         callers, can be cached. *)
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

module Eval_terms: sig
  (** [annot_predicate_deps ~pre ~here p] computes the logic dependencies needed
      to evaluate the predicate [p] in a code annotation in cvalue state [here],
      in a function whose pre-state is [pre].
      Returns None on either an evaluation error or on unsupported construct. *)
  val annot_predicate_deps:
    pre:Cvalue.Model.t -> here:Cvalue.Model.t ->
    Cil_types.predicate -> Locations.Zone.t option
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

module Unit_tests: sig
  (** Currently tested by this module:
      - semantics of sign values. *)

  (** Runs some programmatic tests on Eva. *)
  val run: unit -> unit
end
