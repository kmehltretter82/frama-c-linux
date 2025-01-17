(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
open Eval

(** Results of the analysis of a function call:
    - the list of computed abstract states at the return statement of the called
      function, associated with their partition key;
    - whether the results can safely be stored in the memexec cache. *)
type 'state call_result = {
  states: (Partition.key * 'state) list;
  cacheable: cacheable;
}

(** Analysis of functions, built by the functor [Compute_functions.Make]. *)
module type Compute =
sig
  type state
  type loc
  type value

  (** Analysis of a program from the given main function. Computed states for
      each statement are stored in the result tables of each enabled abstract
      domain. This is called by [Analysis.compute].
      The initial abstract state is computed according to [lib_entry]:
      - if false, non-volatile global variables are initialized according
        to their initializers (zero if no explicit initializer).
      - if true, non-const global variables are initialized at top. *)
  val compute_from_entry_point: kernel_function -> lib_entry:bool -> unit

  (** Analysis of a program from the given main function and initial state. *)
  val compute_from_init_state: kernel_function -> state -> unit

  (** Analysis of a function call during the Eva analysis. This function is
      called by [Transfer_stmt] when interpreting a call statement.
      [compute_call stmt call recursion state] analyzes the call [call] at
      statement [stmt] in the input abstract state [state].
      If [recursion] is not [None], the call is a recursive call. *)
  val compute_call:
    stmt -> (loc, value) call -> recursion option -> state -> state call_result
end


module type S = sig
  (** The four abstractions: values, locations, states and evaluation context,
      plus the evaluation engine for these abstractions. *)
  include Abstractions.S_with_evaluation

  module Compute : Compute
    with type state = Dom.t
     and type value = Val.t
     and type loc = Loc.location
end

(** Access to analysis results, built by [Analysis] and used by [Results],
    which defines the final and complete API to access Eva results. *)
module type Results = sig
  type state
  type value
  type location

  (** {2 Access to abstract states inferred by the analysis} *)

  (** Return the abstract state computed at the start of the analysis,
      as entry point of the main function, after the initialization of global
      variables and main arguments. *)
  val get_global_state: unit -> state or_top_bottom

  (** Return the abstract state inferred before or after a given statement.
      This is the join of the states inferred for each callstack. *)
  val get_stmt_state : after:bool -> stmt -> state or_top_bottom

  (** Return the abstract state inferred before or after a given statement,
      for each callstack in which the analysis has reached the statement.
      The optional argument [selection] allows selecting only some callstacks:
      it is more efficient to select fewer callstacks, if not all are needed. *)
  val get_stmt_state_by_callstack:
    ?selection:Callstack.t list ->
    after:bool -> stmt -> state Callstack.Hashtbl.t or_top_bottom

  (** Return the abstract state inferred at start of a given function.
      This is the join of states inferred for each callstack. *)
  val get_initial_state:
    kernel_function -> state or_top_bottom

  (** Return the abstract state inferred as entry point of the given function,
      for each callstack in which the function has been analyzed.
      The optional argument [selection] allows selecting only some callstacks:
      it is more efficient to select fewer callstacks, if not all are needed. *)
  val get_initial_state_by_callstack:
    ?selection:Callstack.t list ->
    kernel_function -> state Callstack.Hashtbl.t or_top_bottom

  (** {2 Shortcuts for the evaluation in an abstract state} *)

  (** Evaluates the value of an expression in the given state. *)
  val eval_expr : state -> exp -> value evaluated

  (** Evaluates the value of an lvalue in the given state, with possible
      indeterminateness: non-initialization or escaping addresses. *)
  val copy_lvalue: state -> lval -> value flagged_value evaluated

  (** Evaluates the location of an lvalue in the given state, for a read
      access (invalid location for a read access are ignored). *)
  val eval_lval_to_loc: state -> lval -> location evaluated

  (** Evaluates the function argument of a [Call] constructor. *)
  val eval_function_exp:
    state -> ?args:exp list -> exp -> kernel_function list evaluated

  (** [assume_cond stmt state expr b] reduces the given abstract state
      by assuming [exp] evaluates to:
      - a non-zero value if [b] is true;
      - zero if [b] is false. *)
  val assume_cond : stmt -> state -> exp -> bool -> state or_bottom
end

module type S_with_results = sig
  include S
  include Results with type state := Dom.state
                   and type value := Val.t
                   and type location := Loc.location
end
