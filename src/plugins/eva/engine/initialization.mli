(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Creation of the initial state of abstract domain. *)

open Eva_ast
open Lattice_bounds

module type S = sig
  type state

  (** Compute the initial state for an analysis (as in {!initial_state}),
      but also bind the formal parameters of the function given as argument. *)
  val initial_state_with_formals :
    lib_entry:bool -> Cil_types.kernel_function -> state or_bottom

  (** Initializes a local variable in the current state. *)
  val initialize_local_variable:
    pos:Position.t -> varinfo -> init -> state -> state or_bottom
end

module Make
    (Domain: Abstract.Domain.External)
    (_: Evaluation_sig.S with type state = Domain.state
                          and type loc = Domain.location)
    (_: Engine_sig.Transfer_stmt with type state = Domain.t)
  : S with type state := Domain.t
