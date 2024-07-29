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

(** Call [start] when starting analyzing a new callstack. *)
val start: Callstack.t -> unit

(** Call [stop] when finishing analyzing a callstack. *)
val stop: Callstack.t -> unit

(** Reset the internal state of the module. *)
val reset: unit -> unit

(** Display a complete summary of performance informations. Can be
    called during the analysis. *)
val display: Format.formatter -> unit

[@@@ api_start]
(** Statistics about the analysis performance. *)

(** Statistic about the analysis time of a function or a callstack. *)
type stat = {
  nb_calls: int;
  (** How many times the given function or callstack has been analyzed. *)
  self_duration: float;
  (** Time spent analyzing the function or callstack itself. *)
  total_duration: float;
  (** Total time, including the analysis of other functions called. *)
  called: Kernel_function.Hptset.t;
  (** Set of functions called from this function or callstack. *)
}

type 'a by_fun = (Cil_types.kernel_function * 'a) list

(** Returns a list of the functions with the longest total analysis time,
    sorted by decreasing analysis time. Each function [f] is associated to
    its stat and the unsorted list of stats of all function calls from [f]. *)
val compute_stat_by_fun: unit -> (stat * stat by_fun) by_fun

(** Statistics about each analyzed callstack. *)
module StatByCallstack : sig
  type callstack = Cil_types.kernel_function list

  (** Get the current analysis statistic for a callstack. *)
  val get: callstack -> stat

  (** Iterate on the statistic of every analyzed callstack. *)
  val iter: (callstack -> stat -> unit) -> unit

  (** Set a hook on statistics computation *)
  val add_hook_on_change:
    ((callstack, stat) State_builder.hashtbl_event -> unit) -> unit
  [@@@ api_end]

  (** Sub-signature of [State_builder.Hashtbl] required by the server
      to build synchronized arrays. *)

  type key = Cil_types.kernel_function list
  type data = stat
  module Datatype: Datatype.S
  val add_hook_on_update: (Datatype.t -> unit) -> unit
  [@@@ api_start]
end

[@@@ api_end]
