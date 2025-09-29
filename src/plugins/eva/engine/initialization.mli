(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Creation of the initial state of abstract domain. *)

module Make
    (Domain: Abstract.Domain.External)
    (_: Evaluation_sig.S with type state = Domain.state
                          and type loc = Domain.location)
    (_: Engine_sig.Transfer_stmt with type state = Domain.t)
  : Engine_sig.Initialization with type state = Domain.t
