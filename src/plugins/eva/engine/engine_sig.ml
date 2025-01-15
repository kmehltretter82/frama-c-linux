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
