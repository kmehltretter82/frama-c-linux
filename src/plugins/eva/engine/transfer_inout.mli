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

(** Helper module to register read and written memory zones to {!Inout_memory}
    in {!Transfer_stmt} and {!Transfer_specification} *)

module type S = sig
  type location
  type value
  type valuation

  (** [add_logc_assign aloc clause location] registers to [Inout_memory] the
      read and written memory zones at [aloc] for the logic assign [clause] to
      the [location]. *)
  val add_logic_assign :
    Analysis_location.t -> location Eval.logic_assign -> location -> unit

  (** [add_assign_lval aloc valuation lval exp] registers to [Inout_memory] the
      read and written memory zones at [aloc] for the assignment from [exp] to
      [lval] with a given [valuation]. *)
  val add_assign_lval :
    Analysis_location.t -> valuation ->
    Eva_ast.lval -> Eva_ast.exp ->
    unit

  (** [add_assign_var aloc valuation vi exp] registers to [Inout_memory] the
      read and written memory zones at [aloc] for the assignment from [exp] to
      [vi] with a given [valuation]. *)
  val add_assign_var :
    Analysis_location.t -> valuation ->
    Eva_ast.varinfo -> Eva_ast.exp ->
    unit

  (** [add_read_exp aloc valuation exp] registers to [Inout_memory] the read
      memory zones at [aloc] for reading the expression [exp] with a given
      [valuation]. *)
  val add_read_exp :
    Analysis_location.t -> valuation ->
    Eva_ast.exp ->
    unit

  (** [add_call_args aloc valuation call] registers to [Inout_memory] the read
      and written memory zones at [aloc] for the arguments of the given [call]
      with a given [valuation]. *)
  val add_call_args :
    Analysis_location.t -> valuation ->
    (location, value) Eval.call ->
    unit
end

module Make (Engine : Engine_sig.S)
  : S with type location = Engine.Loc.location
       and type value = Engine.Val.t
       and type valuation = Engine.Eval.Valuation.t
