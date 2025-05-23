(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Heuristic for automatic loop unrolling. *)

module Make (Abstract: Abstractions.S_with_evaluation) : sig

  val compute:
    max_unroll:int -> Abstract.Dom.t -> Eva_automata.loop -> int option

end
