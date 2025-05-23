(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

module Make (_ : sig val kf: kernel_function end) : sig
  val widening_delay : int
  val widening_period : int
  val slevel : stmt -> int
  val merge : stmt -> bool
  val unroll : Eva_automata.loop -> Partition.unroll_limit
  val history_size : int
  val universal_splits : Partition.action list
  val flow_actions : stmt -> Partition.action list
  val call_return_policy : Partition.call_return_policy
end
