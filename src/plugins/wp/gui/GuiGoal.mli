(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- PO Details View                                                    --- *)
(* -------------------------------------------------------------------------- *)

class pane : GuiConfig.provers ->
  object

    method select : Wpo.t option -> unit
    method update : unit
    method coerce : GObj.widget

  end
