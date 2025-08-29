(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Composer Panel                                                     --- *)
(* -------------------------------------------------------------------------- *)

class composer : GuiSequent.focused ->
  object

    method clear : unit
    method connect : (unit -> unit) -> unit
    (** request-for-update event *)

    method print :
      GuiTactic.composer -> quit:(unit -> unit) -> Format.formatter -> unit

  end

class browser : GuiSequent.focused ->
  object

    method clear : unit
    method connect : (unit -> unit) -> unit
    (** request-for-update event *)

    method print :
      GuiTactic.browser -> quit:(unit -> unit) -> Format.formatter -> unit

  end
