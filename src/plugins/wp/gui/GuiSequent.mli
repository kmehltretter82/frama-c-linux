(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Sequent Pretty-Printer                                             --- *)
(* -------------------------------------------------------------------------- *)

class focused : Wtext.text ->
  object
    inherit Ptip.pseq
    method popup : unit
    method on_popup : (Widget.popup -> unit) -> unit
    method button : title:string -> callback:(unit -> unit) ->
      Format.formatter -> unit
  end
