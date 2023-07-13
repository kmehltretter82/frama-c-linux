(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

(** Database in which static plugins are registered.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)

(**
   Modules providing general services:
   - {!Dynamic}: API for plug-ins linked dynamically
   - {!Log}: message outputs and printers
   - {!Plugin}: general services for plug-ins
   - {!Project} and associated files: {!Kind}, {!Datatype} and {!State_builder}.

   Other main kernel modules:
   - {!Ast}: the cil AST
   - {!Ast_info}: syntactic value directly computed from the Cil Ast
   - {!File}: Cil file initialization
   - {!Globals}: global variables, functions and annotations
   - {!Annotations}: annotations associated with a statement
   - {!Property_status}: status of annotations
   - {!Kernel_function}: C functions as seen by Frama-C
   - {!Stmts_graph}: the statement graph
   - {!Loop}: (natural) loops
   - {!Visitor}: frama-c visitors
   - {!Kernel}: general parameters of Frama-C (mostly set from the command
     line)
*)

open Cil_types
open Cil_datatype

(* ************************************************************************* *)
(** {2 Registering} *)
(* ************************************************************************* *)

val register: 'a ref -> 'a -> unit
(** Plugins must register values with this function. *)

val register_compute:
  string ->
  State.t list ->
  (unit -> unit) ref -> (unit -> unit) -> State.t

val register_guarded_compute:
  (unit -> bool) ->
  (unit -> unit) ref -> (unit -> unit) -> unit
(** @before 26.0-Iron there was a string parameter (first position) that was
            only used for Journalization, that has been removed. *)

(** Frama-C main interface.
    @since Lithium-20081201
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)
module Main: sig

  val extend : (unit -> unit) -> unit
  (** Register a function to be called by the Frama-C main entry point.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)

  val play: (unit -> unit) ref
  (** Run all the Frama-C analyses. This function should be called only by
      toplevels.
      @since Beryllium-20090901 *)

  (**/**)
  val apply: unit -> unit
  (** Not for casual user. *)
  (**/**)

end

module Toplevel: sig

  val run: ((unit -> unit) -> unit) ref
  (** Run a Frama-C toplevel playing the game given in argument (in
      particular, applying the argument runs the analyses).
      @since Beryllium-20090901 *)

end

(* ************************************************************************* *)
(** {2 Values} *)
(* ************************************************************************* *)

(** Deprecated module: use the Eva.mli API instead. *)
module Value : sig

  type state = Cvalue.Model.t
  (** Internal state of the value analysis. *)

  type t = Cvalue.V.t
  (** Internal representation of a value. *)

  val emitter: Emitter.t ref
  (** Emitter used by Value to emit statuses *)

  val proxy: State_builder.Proxy.t

  val self : State.t
  (** Internal state of the value analysis from projects viewpoint.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)

  val mark_as_computed: unit -> unit
  (** Indicate that the value analysis has been done already. *)

  val compute : (unit -> unit) ref
  (** Compute the value analysis using the entry point of the current
      project. You may set it with {!Globals.set_entry_point}.
      @raise Globals.No_such_entry_point if the entry point is incorrect
      @raise Db.Value.Incorrect_number_of_arguments if some arguments are
      specified for the entry point using {!Db.Value.fun_set_args}, and
      an incorrect number of them is given.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)

  val is_computed: unit -> bool
  (** Return [true] iff the value analysis has been done.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)

  [@@@alert "-db_deprecated"]

  type callstack = Eva_types.Callstack.callstack

  module Table_By_Callstack:
    State_builder.Hashtbl with type key = stmt
                           and type data = state Eva_types.Callstack.Hashtbl.t
  (** Table containing the results of the value analysis, ie.
      the state before the evaluation of each reachable statement. *)

  module AfterTable_By_Callstack:
    State_builder.Hashtbl with type key = stmt
                           and type data = state Eva_types.Callstack.Hashtbl.t
  (** Table containing the state of the value analysis after the evaluation
      of each reachable and evaluable statement. Filled only if
      [Value_parameters.ResultsAfter] is set. *)

  val ignored_recursive_call: kernel_function -> bool
  (** This functions returns true if the value analysis found and ignored
      a recursive call to this function during the analysis. *)

  val condition_truth_value: stmt -> bool * bool
  (** Provided [stmt] is an 'if' construct, [fst (condition_truth_value stmt)]
      (resp. snd) is true if and only if the condition of the 'if' has been
      evaluated to true (resp. false) at least once during the analysis. *)

  (** {3 Parameterization} *)

  val use_spec_instead_of_definition: (kernel_function -> bool) ref
  (** To be called by derived analyses to determine if they must use
      the body of the function (if available), or only its spec. Used for
      value builtins, and option -val-use-spec. *)


  (** {4 Arguments of the main function} *)

  (** The functions below are related to the arguments that are passed to the
      function that is analysed by the value analysis. Specific arguments
      are set by [fun_set_args]. Arguments reset to default values when
      [fun_use_default_args] is called, when the ast is changed, or
      if the options [-libentry] or [-main] are changed. *)

  (** Specify the arguments to use. *)
  val fun_set_args : t list -> unit

  val fun_use_default_args : unit -> unit

  (** For this function, the result [None] means that
      default values are used for the arguments. *)
  val fun_get_args : unit -> t list option

  exception Incorrect_number_of_arguments
  (** Raised by [Db.Compute] when the arguments set by [fun_set_args]
      are not coherent with the prototype of the function (if there are
      too few or too many of them) *)


  (** {4 Initial state of the analysis} *)

  (** The functions below are related to the value of the global variables
      when the value analysis is started. If [globals_set_initial_state] has not
      been called, the given state is used. A default state (which depends on
      the option [-libentry]) is used when [globals_use_default_initial_state]
      is called, or when the ast changes. *)

  (** Specify the initial state to use. *)
  val globals_set_initial_state : state -> unit

  val globals_use_default_initial_state : unit -> unit

  (** Initial state used by the analysis *)
  val globals_state : unit -> state


  (** @return [true] if the initial state for globals used by the value
      analysis has been supplied by the user (through
      [globals_set_initial_state]), or [false] if it is automatically
      computed by the value analysis *)
  val globals_use_supplied_state : unit -> bool


  (** {3 Getters} *)
  (** State of the analysis at various points *)

  val get_initial_state : kernel_function -> state
  val get_initial_state_callstack :
    kernel_function -> state Eva_types.Callstack.Hashtbl.t option
  val get_state : ?after:bool -> kinstr -> state
  (** [after] is false by default. *)

  val get_stmt_state_callstack:
    after:bool -> stmt -> state Eva_types.Callstack.Hashtbl.t option

  val get_stmt_state : ?after:bool -> stmt -> state
  (** [after] is false by default.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)

  val fold_stmt_state_callstack :
    (state -> 'a -> 'a) -> 'a -> after:bool -> stmt -> 'a

  val fold_state_callstack :
    (state -> 'a -> 'a) -> 'a -> after:bool -> kinstr -> 'a

  val find : state -> Locations.location ->  t

  (** {3 Evaluations} *)

  val eval_lval :
    (?with_alarms:CilE.warn_mode ->
     Locations.Zone.t option ->
     state ->
     lval ->
     Locations.Zone.t option * t) ref

  val eval_expr :
    (?with_alarms:CilE.warn_mode -> state -> exp -> t) ref

  val eval_expr_with_state :
    (?with_alarms:CilE.warn_mode -> state -> exp -> state * t) ref

  val reduce_by_cond:
    (state -> exp -> bool -> state) ref

  val find_lv_plus :
    (Cvalue.Model.t -> Cil_types.exp ->
     (Cil_types.lval * Ival.t) list) ref
  (** returns the list of all decompositions of [expr] into the sum an lvalue
      and an interval. *)

  (** {3 Values and kernel functions} *)

  val expr_to_kernel_function :
    (kinstr
     -> ?with_alarms:CilE.warn_mode
     -> deps:Locations.Zone.t option
     -> exp
     -> Locations.Zone.t * Kernel_function.Hptset.t) ref

  val expr_to_kernel_function_state :
    (state
     -> deps:Locations.Zone.t option
     -> exp
     -> Locations.Zone.t * Kernel_function.Hptset.t) ref

  exception Not_a_call
  val call_to_kernel_function : stmt -> Kernel_function.Hptset.t
  (** Return the functions that can be called from this call.
      @raise Not_a_call if the statement is not a call. *)

  val valid_behaviors: (kernel_function -> state -> funbehavior list) ref

  val add_formals_to_state: (state -> kernel_function -> exp list -> state) ref
  (** [add_formals_to_state state kf exps] evaluates [exps] in [state]
      and binds them to the formal arguments of [kf] in the resulting
      state *)

  (** {3 Reachability} *)

  val is_accessible : kinstr -> bool
  val is_reachable : state -> bool
  (** @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)

  val is_reachable_stmt : stmt -> bool

  (** {3 About kernel functions} *)

  exception Void_Function
  val find_return_loc : kernel_function -> Locations.location
  (** Return the location of the returned lvalue of the given function.
      @raise Void_Function if the function does not return any value. *)

  val is_called: (kernel_function -> bool) ref

  val callers: (kernel_function -> (kernel_function*stmt list) list) ref
  (** @return the list of callers with their call sites. Each function is
      present only once in the list. *)

  (** {3 State before a kinstr} *)

  val access : (kinstr -> lval ->  t) ref
  val access_expr : (kinstr -> exp ->  t) ref
  val access_location : (kinstr -> Locations.location ->  t) ref


  (** {3 Locations of left values} *)

  val lval_to_loc :
    (kinstr -> ?with_alarms:CilE.warn_mode -> lval -> Locations.location) ref

  val lval_to_loc_with_deps :
    (kinstr
     -> ?with_alarms:CilE.warn_mode
     -> deps:Locations.Zone.t
     -> lval
     -> Locations.Zone.t * Locations.location) ref

  val lval_to_loc_with_deps_state :
    (state
     -> deps:Locations.Zone.t
     -> lval
     -> Locations.Zone.t * Locations.location) ref

  val lval_to_loc_state :
    (state -> lval -> Locations.location) ref

  val lval_to_offsetmap :
    ( kinstr -> ?with_alarms:CilE.warn_mode -> lval ->
      Cvalue.V_Offsetmap.t option) ref

  val lval_to_offsetmap_state :
    (state -> lval -> Cvalue.V_Offsetmap.t option) ref
  (** @since Carbon-20110201 *)

  val lval_to_zone :
    (kinstr -> ?with_alarms:CilE.warn_mode -> lval -> Locations.Zone.t) ref

  val lval_to_zone_state :
    (state -> lval -> Locations.Zone.t) ref
  (** Does not emit alarms. *)

  val lval_to_zone_with_deps_state:
    (state -> for_writing:bool -> deps:Locations.Zone.t option -> lval ->
     Locations.Zone.t * Locations.Zone.t * bool) ref
  (** [lval_to_zone_with_deps_state state ~for_writing ~deps lv] computes
      [res_deps, zone_lv, exact], where [res_deps] are the memory zones needed
      to evaluate [lv] in [state] joined  with [deps]. [zone_lv] contains the
      valid memory zones that correspond to the location that [lv] evaluates
      to in [state]. If [for_writing] is true, [zone_lv] is restricted to
      memory zones that are writable. [exact] indicates that [lv] evaluates
      to a valid location of cardinal at most one. *)

  val lval_to_precise_loc_state:
    (?with_alarms:CilE.warn_mode -> state -> lval ->
     state * Precise_locs.precise_location * typ) ref

  val lval_to_precise_loc_with_deps_state:
    (state -> deps:Locations.Zone.t option -> lval ->
     Locations.Zone.t * Precise_locs.precise_location) ref


  (** Evaluation of the [\from] clause of an [assigns] clause.*)
  val assigns_inputs_to_zone :
    (state -> assigns -> Locations.Zone.t) ref

  (** Evaluation of the left part of [assigns] clause (without [\from]).*)
  val assigns_outputs_to_zone :
    (state -> result:varinfo option -> assigns -> Locations.Zone.t) ref

  (** Evaluation of the left part of [assigns] clause (without [\from]). Each
      assigns term results in one location. *)
  val assigns_outputs_to_locations :
    (state -> result:varinfo option -> assigns -> Locations.location list) ref

  (** For internal use only. Evaluate the [assigns] clause of the
      given function in the given prestate, compare it with the
      computed froms, return warning and set statuses. *)
  val verify_assigns_froms :
    (Kernel_function.t -> pre:state -> Function_Froms.t -> unit) ref


  (** {3 Evaluation of logic terms and predicates} *)
  module Logic : sig
    (** The APIs of this module are not stabilized yet, and are subject
        to change between Frama-C versions. *)

    val eval_predicate:
      (pre:state -> here:state -> predicate ->
       Property_status.emitted_status) ref
      (** Evaluate the given predicate in the given states for the Pre
          and Here ACSL labels.
          @since Neon-20140301 *)
  end


  (** {3 Callbacks} *)

  (** Actions to perform at end of each function analysis. Not compatible with
      option [-memexec-all] *)

  module Record_Value_Callbacks:
    Hook.Iter_hook
    with type param = callstack * (state Stmt.Hashtbl.t) Lazy.t

  module Record_Value_Superposition_Callbacks:
    Hook.Iter_hook
    with type param = callstack * (state list Stmt.Hashtbl.t) Lazy.t

  module Record_Value_After_Callbacks:
    Hook.Iter_hook
    with type param = callstack * (state Stmt.Hashtbl.t) Lazy.t

  (**/**)
  (* Temporary API, do not use *)
  module Record_Value_Callbacks_New: Hook.Iter_hook
    with type param =
           callstack *
           ((state Stmt.Hashtbl.t) Lazy.t  (* before states *) *
            (state Stmt.Hashtbl.t) Lazy.t) (* after states *)
             Value_types.callback_result
  (**/**)

  val no_results: (fundec -> bool) ref
  (** Returns [true] if the user has requested that no results should
      be recorded for this function. If possible, hooks registered
      on [Record_Value_Callbacks] and [Record_Value_Callbacks_New]
      should not force their lazy argument *)

  (** Actions to perform at each treatment of a "call"
      statement. [state] is the state before the call.
      @deprecated Use Call_Type_Value_Callbacks instead. *)
  module Call_Value_Callbacks:
    Hook.Iter_hook with type param = state * callstack

  (** Actions to perform at each treatment of a "call"
      statement. [state] is the state before the call.
      @since Aluminium-20160501  *)
  module Call_Type_Value_Callbacks:
    Hook.Iter_hook with type param =
                          [`Builtin | `Spec | `Def | `Reuse]
                          * state * callstack


  (** Actions to perform whenever a statement is handled. *)
  module Compute_Statement_Callbacks:
    Hook.Iter_hook with type param = stmt * callstack * state list

  (* -remove-redundant-alarms feature, applied at the end of an Eva analysis,
     fulfilled by the Scope plugin that also depends on Eva. We thus use a
     reference here to avoid a cyclic dependency. *)
  val rm_asserts: (unit -> unit) ref


  (** {3 Pretty printing} *)

  val pretty : Format.formatter -> t -> unit
  val pretty_state : Format.formatter -> state -> unit


  val display : (Format.formatter -> kernel_function -> unit) ref

  (**/**)
  (** {3 Internal use only} *)

  val noassert_get_state : ?after:bool -> kinstr -> state
  (** To be used during the value analysis itself (instead of
      {!get_state}). [after] is false by default. *)

  val recursive_call_occurred: kernel_function -> unit

  val merge_conditions: int Cil_datatype.Stmt.Hashtbl.t -> unit
  val mask_then: int
  val mask_else: int

  val initial_state_only_globals : (unit -> state) ref

  val update_callstack_table: after:bool -> stmt -> callstack -> state -> unit
  (* Merge a new state in the table indexed by callstacks. *)


  val memoize : (kernel_function -> unit) ref
  (*  val compute_call :
      (kernel_function -> call_kinstr:kinstr -> state ->  (exp*t) list
         -> Cvalue.V_Offsetmap.t option (** returned value of [kernel_function] *) * state) ref
  *)
  val merge_initial_state : callstack -> kernel_function -> state -> unit
  (** Store an additional possible initial state for the given callstack as
      well as its values for actuals. *)

  val initial_state_changed: (unit -> unit) ref
end
[@@alert db_deprecated
    "Db.Value is deprecated and will be removed in a future version \
     of Frama-C. Please use the Eva.mli public API instead."]

(** Functional dependencies between function inputs and function outputs.
    @see <../from/index.html> internal documentation. *)
module From : sig

  (** exception raised by [find_deps_no_transitivity_*] if the given expression
      is not an lvalue.
      @since Aluminium-20160501
  *)
  exception Not_lval

  val find_deps_no_transitivity : (stmt -> exp -> Locations.Zone.t) ref

  val find_deps_no_transitivity_state :
    (Cvalue.Model.t -> exp -> Locations.Zone.t) ref

  (** @raise Not_lval if the given expression is not a C lvalue. *)
  val find_deps_term_no_transitivity_state :
    (Cvalue.Model.t -> term -> Value_types.logic_dependencies) ref

end
[@@alert db_deprecated
    "Db.From is deprecated and will be removed in a future version \
     of Frama-C. Please use the From module or the Eva API instead."]

(* ************************************************************************* *)
(** {2 Plugins} *)
(* ************************************************************************* *)

(** Declarations common to the various postdominators-computing modules *)
module PostdominatorsTypes: sig

  exception Top
  (** Used for postdominators-related functions, when the
      postdominators of a statement cannot be computed. It means that
      there is no path from this statement to the function return. *)

  module type Sig = sig
    val compute: (kernel_function -> unit) ref

    val stmt_postdominators:
      (kernel_function -> stmt -> Stmt.Hptset.t) ref
    (** @raise Top (see above) *)

    val is_postdominator:
      (kernel_function -> opening:stmt -> closing:stmt -> bool) ref

    val display: (unit -> unit) ref

    val print_dot : (string -> kernel_function -> unit) ref
    (** Print a representation of the postdominators in a dot file
        whose name is [basename.function_name.dot]. *)
  end
end

(** Syntactic postdominators plugin.
    @see <../postdominators/index.html> internal documentation. *)
module Postdominators: PostdominatorsTypes.Sig

(** Postdominators using value analysis results.
    @see <../postdominators/index.html> internal documentation. *)
module PostdominatorsValue: PostdominatorsTypes.Sig

(** Security analysis.
    @see <../security/index.html> internal documentation. *)
module Security : sig

  val run_whole_analysis: (unit -> unit) ref
  (** Run all the security analysis. *)

  val run_ai_analysis: (unit -> unit) ref
  (** Only run the analysis by abstract interpretation. *)

  val run_slicing_analysis: (unit -> Project.t) ref
  (** Only run the security slicing pre-analysis. *)

  val self: State.t ref

end

(** Signature common to some Inout plugin options. The results of
    the computations are available on a per function basis. *)
module type INOUTKF = sig

  type t

  val self_internal: State.t ref
  val self_external: State.t ref

  val compute : (kernel_function -> unit) ref

  val get_internal : (kernel_function -> t) ref
  (** Inputs/Outputs with local and formal variables *)

  val get_external : (kernel_function -> t) ref
  (** Inputs/Outputs without either local or formal variables *)

  (** {3 Pretty printing} *)

  val display : (Format.formatter -> kernel_function -> unit) ref
  val pretty : Format.formatter -> t -> unit

end

(** Signature common to inputs and outputs computations. The results
    are also available on a per-statement basis. *)
module type INOUT = sig
  include INOUTKF

  val statement : (stmt -> t) ref
  val kinstr : kinstr -> t option
end

(** State_builder.of read inputs.
    That is over-approximation of zones read by each function.
    @see <../inout/Inputs.html> internal documentation. *)
module Inputs : sig

  include INOUT with type t = Locations.Zone.t

  val expr : (stmt -> exp -> t) ref

  val self_with_formals: State.t ref

  val get_with_formals : (kernel_function -> t) ref
  (** Inputs with formals and without local variables *)

  val display_with_formals: (Format.formatter -> kernel_function -> unit) ref

end

(** State_builder.of outputs.
    That is over-approximation of zones written by each function.
    @see <../inout/Outputs.html> internal documentation. *)
module Outputs : sig
  include INOUT with type t = Locations.Zone.t
  val display_external : (Format.formatter -> kernel_function -> unit) ref
end

(** State_builder.of operational inputs.
    That is:
    - over-approximation of zones whose input values are read by each function,
      State_builder.of sure outputs
    - under-approximation of zones written by each function.
      @see <../inout/Context.html> internal documentation. *)
module Operational_inputs : sig
  include INOUTKF with type t = Inout_type.t
  val get_internal_precise: (?stmt:stmt -> kernel_function -> Inout_type.t) ref
  (** More precise version of [get_internal] function. If [stmt] is
      specified, and is a possible call to the given kernel_function,
      returns the operational inputs for this call. *)

  (**/**)
  (* Internal use *)
  module Record_Inout_Callbacks:
    Hook.Iter_hook with type param = Eva_types.Callstack.t * Inout_type.t
    [@@alert "-db_deprecated"]
    (**/**)
end


(**/**)
(** Do not use yet.
    @see <../inout/Derefs.html> internal documentation. *)
module Derefs : INOUT with type t = Locations.Zone.t
(**/**)

(** {3 GUI} *)

(** This function should be called from time to time by all analysers taking
    time. In GUI mode, this will make the interface reactive.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide
    @deprecated 21.0-Scandium *)
val progress: (unit -> unit) ref
[@@ deprecated "Use Db.yield instead."]

(** Registered daemon on progress. *)
type daemon

(**
   [on_progress ?debounced ?on_delayed trigger] registers [trigger] as new
   daemon to be executed on each {!yield}.
   @param debounced the least amount of time between two successive calls to the
   daemon, in milliseconds (default is 0ms).
   @param on_delayed callback is invoked as soon as the time since the last
   {!yield} is greater than [debounced] milliseconds (or 100ms at least).
   @param on_finished callback is invoked when the callback is unregistered.
*)
val on_progress :
  ?debounced:int -> ?on_delayed:(int -> unit) -> ?on_finished:(unit -> unit) ->
  (unit -> unit) -> daemon

(** Unregister the [daemon]. *)
val off_progress : daemon -> unit

(** [while_progress ?debounced ?on_delayed ?on_finished trigger] is similar to
    [on_progress] but the daemon is automatically unregistered
    as soon as [trigger] returns [false].
    Same optional parameters than [on_progress].
*)
val while_progress :
  ?debounced:int -> ?on_delayed:(int -> unit) -> ?on_finished:(unit -> unit) ->
  (unit -> bool) -> unit

(**
   [with_progress ?debounced ?on_delayed trigger job data] executes the given
   [job] on [data] while registering [trigger] as temporary (debounced) daemon.
   The daemon is finally unregistered at the end of the computation.
   Same optional parameters than [on_progress].
*)
val with_progress :
  ?debounced:int -> ?on_delayed:(int -> unit) -> ?on_finished:(unit -> unit) ->
  (unit -> unit) -> ('a -> 'b) -> 'a -> 'b

(** Trigger all daemons immediately. *)
val flush : unit -> unit

(** Trigger all registered daemons (debounced).
    This function should be called from time to time by all analysers taking
    time. In GUI or Server mode, this will make the clients responsive. *)
val yield : unit -> unit

(** Interrupt the currently running job: the next call to {!yield}
    will raise a [Cancel] exception. *)
val cancel : unit -> unit

(**
   Pauses the currently running process for the specified time, in milliseconds.
   Registered daemons, if any, will be regularly triggered during this waiting
   time at a reasonable period with respect to their debouncing constraints.
*)
val sleep : int -> unit

(** This exception may be raised by {!yield} to interrupt computations. *)
exception Cancel

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
