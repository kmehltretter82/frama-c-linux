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

  val proxy: State_builder.Proxy.t

  val self : State.t
  (** Internal state of the value analysis from projects viewpoint.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)

  val compute : (unit -> unit) ref
  (** Compute the value analysis using the entry point of the current
      project. You may set it with {!Globals.set_entry_point}.
      @raise Globals.No_such_entry_point if the entry point is incorrect
      @raise Db.Value.Incorrect_number_of_arguments if some arguments are
      specified for the entry point using {!Db.Value.fun_set_args}, and
      an incorrect number of them is given.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> Plug-in Development Guide *)

  val condition_truth_value: stmt -> bool * bool
  (** Provided [stmt] is an 'if' construct, [fst (condition_truth_value stmt)]
      (resp. snd) is true if and only if the condition of the 'if' has been
      evaluated to true (resp. false) at least once during the analysis. *)

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

  (**/**)
  (** {3 Internal use only} *)

  val merge_conditions: int Cil_datatype.Stmt.Hashtbl.t -> unit
  val mask_then: int
  val mask_else: int

  val initial_state_only_globals : (unit -> state) ref

  val initial_state_changed: (unit -> unit) ref
end
[@@alert db_deprecated
    "Db.Value is deprecated and will be removed in a future version \
     of Frama-C. Please use the Eva.mli public API instead."]

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
  module Record_Inout_Callbacks: Hook.Iter_hook with type param = Inout_type.t
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
