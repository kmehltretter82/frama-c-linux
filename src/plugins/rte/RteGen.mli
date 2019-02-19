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

(* --- included from visit.mli --- *)
module Visit :
sig

  open Cil_types

  (** {2 RTE Generator API}

      The all-in-one entry points of the RTE plugin.
  *)

  (** Generates RTE for a single function. Uses the status of the various
        RTE options do decide which kinds of annotations must be generated.
  *)
  val annotate_kf: kernel_function -> unit

  (** Generates all RTEs for a given function. *)
  val do_all_rte: kernel_function -> unit

  (** Generates all RTEs except preconditions for a given function. *)
  val do_rte: kernel_function -> unit

  val rte_annotations: stmt -> code_annotation list
  val do_stmt_annotations: kernel_function -> stmt -> code_annotation list
  val do_exp_annotations: kernel_function -> stmt -> exp -> code_annotation list

  (** Main entry point of the plug-in, used by [-rte] option: computes
      RTE on the whole AST. Which kind of RTE is generated depends on the
      options given on the command line.
  *)
  val compute: unit -> unit

  (** {2 Low Level Iterator Control} *)

  (** Flags for controling the low-level API. Each flag control whether
      a category of alarms will be visited or not. *)
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

  (** Defaults flags are taken from the Kernel and RTE plug-in options. *)
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

  (** All flags set to [true]. *)
  val flags_all : flags

  (** All flags set to [false]. *)
  val flags_none : flags

  (** {2 Low-Level RTE Iterators}

      RTE Iterators allow to traverse a Cil AST fragment (stmt, expr, l-value)
      and reveal its potential Alarms. Each alarm will be presented to a callback
      with type [on_alarm], that you can use in turn to generate an annotation
      or perform any other treatment.

      Flags can be used to select which alarm categories to visit, with
      defaults derived from Kernel and RTE plug-in parameters.
  *)

  (** Alarm callback.

      The [on_alarm kf stmt ~invalid alarm] callback is invoked on each
      alarm visited by an RTE iterator, provided it fits the selected categories.
      The [kf] and [stmt] designates the statement originating the alarm,
      while [~invalid:true] is set when the alarm trivially evaluates to false.
      In this later case, the corresponding annotation shall be assigned
      the status [False_if_reachable].

  *)
  type on_alarm = kernel_function -> stmt -> invalid:bool -> Alarms.alarm -> unit

  (** Type of low-level iterators visiting an element ['a] of the AST *)
  type 'a iterator =
    ?flags:flags -> on_alarm ->
    Kernel_function.t -> Cil_types.stmt -> 'a -> unit

  val iter_lval : lval iterator
  val iter_exp : exp iterator
  val iter_instr : instr iterator
  val iter_stmt : stmt iterator

  (** {2 Alarm Helpers} *)

  (** Returns a [False_if_reachable] status when invalid. *)
  val status : invalid:bool -> Property_status.emitted_status option

  (** Registers and returns the annotation associated with the alarm,
      and a boolean flag indicating whether it has been freshly generated
      or not. *)
  val annotation :
    Emitter.t -> kernel_function -> stmt -> invalid:bool -> Alarms.alarm ->
    code_annotation * bool

  (** A callback that simply register the annotation associated with the alarm. *)
  val register : Emitter.t -> on_alarm

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)


end
