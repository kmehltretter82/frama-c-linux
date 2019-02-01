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

  (** Low-level control over iterators *)

  type flags = {
    remove_trivial: bool;
    initialized: bool;
    mem_access: bool;
    div_mod: bool;
    shift: bool;
    left_shift_negative: bool;
    right_shift_negative: bool;
    signed_overflow: bool;
    unsigned_overflow: bool;
    signed_downcast: bool;
    unsigned_downcast: bool;
    float_to_int: bool;
    finite_float: bool;
    pointer_call: bool;
    bool_value: bool;
  }

  (** Defaults are taken from the Kernel and RTE plug-in options *)
  val default :
    ?remove_trivial:bool ->
    ?initialized:bool ->
    ?mem_access:bool ->
    ?div_mod:bool ->
    ?shift:bool ->
    ?left_shift_negative:bool ->
    ?right_shift_negative:bool ->
    ?signed_overflow:bool ->
    ?unsigned_overflow:bool ->
    ?signed_downcast:bool ->
    ?unsigned_downcast:bool ->
    ?float_to_int:bool ->
    ?finite_float:bool ->
    ?pointer_call:bool ->
    ?bool_value:bool ->
    unit -> flags

  (** All flags set to [true] *)
  val flags_all : flags

  (** All flags set to [false] *)
  val flags_none : flags

  (** Low-level iterators callback.

      The [on_alarm stmt ?status alarm] callback is invoked with
      the [stmt] originating the alarm and the already known status,
      if any.
  *)
  type on_alarm =
    kinstr -> ?status:Property_status.emitted_status ->
    Alarms.alarm -> unit

  (** Low-level iterators

      The [on_alarm ki ?status alarm] callback is invoked with
      the k-instruction originating the alarm and the already known status,
      if any.

      Potential alarms can be specified by the provided flags,
      with defaults from the Kernel and RTE plug-in options.
  *)

  type 'a iterator =
    ?flags:flags -> on_alarm ->
    Kernel_function.t ->
    Cil_types.stmt ->
    'a -> unit

  val iter_lval : lval iterator
  val iter_exp : exp iterator
  val iter_instr : instr iterator
  val iter_stmt : stmt iterator

end
