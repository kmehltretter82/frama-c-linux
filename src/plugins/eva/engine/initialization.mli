(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Creation of the initial state of abstract domain. *)

module Make (Engine: Engine_sig.S) :
  Engine_sig.Initialization with type state = Engine.Dom.t
