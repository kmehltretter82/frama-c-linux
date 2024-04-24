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

open Cil_types

(** {2 Callstacks related types and functions} *)

(** Functions dealing with call stacks. *)

(** Clears the current callstack: future accesses to the current callstack
    will fail. *)
val clear_call_stack : unit -> unit

(** Initializes the current callstack with the main entry point. *)
val init_call_stack : kernel_function -> Callstack.t

(** Push a new call to the current callstack. *)
val push_call_stack : kernel_function -> stmt -> unit

(** Removes the topmost call from the current callstack. *)
val pop_call_stack : unit -> unit

(** Returns the current function, at the top of the current callstack.
    Fails if no callstack has been initialized. This should only be called
    during the analysis of a function. *)
val current_kf : unit -> kernel_function

(** Returns the current callstack; fails if it has not been initialized.
    This should only be called during the analysis of a function. *)
val current_call_stack : unit -> Callstack.t

(** Returns the current callstack, or [None] if it has not been initialized. *)
val current_call_stack_opt : unit -> Callstack.t option

(** Prints the current callstack. *)
val pp_callstack : Format.formatter -> unit

(** {2 Others} *)

(* TODO: Document the rest of this file. *)
val emitter : Emitter.t
val get_slevel : Kernel_function.t -> Parameters.SlevelFunction.value
val get_subdivision: stmt -> int
val pretty_actuals :
  Format.formatter -> (Cil_types.exp * Cvalue.V.t) list -> unit
val pretty_current_cfunction_name : Format.formatter -> unit
val warning_once_current : ('a, Format.formatter, unit) format -> 'a

(** Emit an alarm, either as warning or as a result, according to
    status associated to {!Self.wkey_alarm} *)
val alarm_report: 'a Log.pretty_printer

(** [protect f ~cleanup] runs [f]. On a user interruption or a Frama-C error,
    if option -save is set, applies [cleanup]. This is used to clean up and
    save partial results when the analysis is aborted. *)
val protect: (unit -> 'a) -> cleanup:(unit -> unit) -> 'a

(* Statements for which the analysis has degenerated. [true] means that this is
   the statement on which the degeneration occurred, or a statement above in
   the callstack *)
module DegenerationPoints:
  State_builder.Hashtbl with type key = stmt and type data = bool


val create_new_var: string -> typ -> varinfo
(** Create and register a new variable inside Frama-C. The variable
    has its [vlogic] field set, meaning it is not a source variable. The
    freshness of the name must be ensured by the user. *)

val is_const_write_invalid: typ -> bool
(** Detect that the type is const, and that option [-global-const] is set. In
    this case, we forbid writing in a l-value that has this type. *)

val find_return_var: kernel_function -> varinfo option
(** Returns the varinfo returned by the given function.
    Returns None if the function returns void or has no return statement. *)

val postconditions_mention_result: Cil_types.funspec -> bool
(** Does the post-conditions of this specification mention [\result]? *)

val conv_comp: binop -> Abstract_interp.Comp.t
val conv_relation: relation -> Abstract_interp.Comp.t

val normalize_as_cond: exp -> bool -> exp
(** [normalize_as_cond e positive] returns the expression corresponding to
    [e != 0] when [positive] is true, and [e == 0] otherwise. The
    resulting expression will always have a comparison operation at its
    root. *)

val is_value_zero: exp -> bool
(** Return [true] iff the argument has been created by {!normalize_as_cond} *)

val lval_to_exp: lval -> exp
(** This function is memoized to avoid creating too many expressions *)


(** Dependences of expressions and lvalues. *)

val zone_of_expr:
  (lval -> Precise_locs.precise_location) -> exp -> Locations.Zone.t
(** Given a function computing the location of lvalues, computes the memory zone
    on which the value of an expression depends. *)

val indirect_zone_of_lval:
  (lval -> Precise_locs.precise_location) -> lval -> Locations.Zone.t
(** Given a function computing the location of lvalues, computes the memory zone
    on which the offset and the pointer expression (if any) of an lvalue depend.
*)

val deps_of_expr:
  (lval -> Precise_locs.precise_location) -> exp -> Deps.t
(** Given a function computing the location of lvalues, computes the memory
    dependencies of an expression. *)

val deps_of_lval: (lval -> Precise_locs.precise_location) -> lval -> Deps.t
(** Given a function computing the location of lvalues, computes the memory
    dependencies of an lvalue. *)

(** Computes the height of an expression, that is the maximum number of nested
    operations in this expression. *)
val height_expr: exp -> int

(** Computes the height of an lvalue. *)
val height_lval: lval -> int

val skip_specifications: kernel_function -> bool
(** Should we skip the specifications of this function, according to
    [-eva-skip-stdlib-specs] *)

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
