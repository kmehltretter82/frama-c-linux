(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

(** Some functions are also registered in {!Db.Value}. *)

open Cil_types

module Visit :
sig

  (** Low-level iterator

      [generator ~options:... on_alarm kf stmt element] iterates over
      potential alarms for Cil element, located in the given
      kernel_function and stmt.

      The [on_alarm ki ?status alarm] callback is invoked with
      the k-instruction originating the alarm and the already known status,
      if any.

      Potential alarms can be specified by the provided options,
      with defaults generated from the Kernel options and the RTE plug-in
      options.
  *)
  type 'a generator =
    ?remove_trivial:bool ->
    ?initialized:Options.DoInitialized.t ->
    ?mem_access:Options.DoMemAccess.t ->
    ?div_mod:Options.DoDivMod.t ->
    ?shift:Options.DoShift.t ->
    ?left_shift_negative:Kernel.LeftShiftNegative.t ->
    ?right_shift_negative:Kernel.RightShiftNegative.t ->
    ?signed_overflow:Kernel.SignedOverflow.t ->
    ?unsigned_overflow:Kernel.UnsignedOverflow.t ->
    ?signed_downcast:Kernel.SignedDowncast.t ->
    ?unsigned_downcast:Kernel.UnsignedDowncast.t ->
    ?float_to_int:Options.DoFloatToInt.t ->
    ?finite_float:bool ->
    ?pointer_call:Options.DoPointerCall.t ->
    ?bool_value:Kernel.InvalidBool.t ->
    (Cil_types.kinstr ->
     ?status:Property_status.emitted_status -> Alarms.alarm -> unit) ->
    Kernel_function.t ->
    Cil_types.stmt ->
    'a -> unit

  val iter_lval : lval generator
  val iter_exp : exp generator
  val iter_instr : instr generator
  val iter_stmt : stmt generator

end
