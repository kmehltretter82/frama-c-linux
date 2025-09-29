(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Eval

module Make
    (Engine: Engine_sig.S)
    (_ : Engine_sig.Transfer_logic with type state = Engine.Dom.t)
  : sig

    val treat_statement_assigns:
      pos:Position.t -> assigns -> Engine.Dom.t -> Engine.Dom.t

    val compute_using_specification:
      warn:bool ->
      (Engine.Loc.location, Engine.Val.t) call -> spec ->
      Engine.Dom.t -> (Partition.key*Engine.Dom.t) list

  end
