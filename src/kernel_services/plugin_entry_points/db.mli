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
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)

(**
   Modules providing general services:
   - {!Dynamic}: API for plug-ins linked dynamically
   - {!Log}: message outputs and printers
   - {!Plugin}: general services for plug-ins
   - {!Project} and associated files: {!Datatype} and {!State_builder}.

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
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)
module Main: sig

  val extend : (unit -> unit) -> unit
  (** Register a function to be called by the Frama-C main entry point.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)

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

module Postdominators: PostdominatorsTypes.Sig

(** {3 GUI} *)

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
