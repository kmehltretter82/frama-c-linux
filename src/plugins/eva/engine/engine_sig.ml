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

type 'state call_result = {
  states: (Partition.key * 'state) list;
  cacheable: cacheable;
}

module type Compute =
sig
  type state
  type loc
  type value

  (** Compute a call to the main function. *)
  val compute_from_entry_point: kernel_function -> lib_entry:bool -> unit

  (** Compute a call to the main function from the given initial state. *)
  val compute_from_init_state: kernel_function -> state -> unit

  (** Compute a call during an analysis *)
  val compute_call:
    stmt -> (loc, value) call -> recursion option -> state -> state call_result
end


module type S = sig
  (* The four abstractions (values, locations, states and evaluation context). *)
  include Abstractions.S

  (* The evaluator for these abstractions *)
  module Eval : Evaluation_sig.S
    with type state = Dom.t
     and type context = Ctx.t
     and type value = Val.t
     and type loc = Loc.location
     and type origin = Dom.origin

  module Compute : Compute
    with type state = Dom.t
     and type value = Val.t
     and type loc = Loc.location
end
