(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(** Mark the analysis as aborted: it will be stopped at the next safe point. *)
val signal_abort: kill:bool -> unit

(** Reset the signal sent by [signal_abort], if any. *)
val signal_reset: unit -> unit

(** Provided [stmt] is an 'if' construct, [fst (condition_truth_value stmt)]
    (resp. snd) is true if and only if the condition of the 'if' has been
    evaluated to true (resp. false) at least once during the analysis. *)
val condition_truth_value: stmt -> bool * bool

module Make (Engine: Engine_sig.S) :
  Engine_sig.Iterator with type state = Engine.Dom.t
