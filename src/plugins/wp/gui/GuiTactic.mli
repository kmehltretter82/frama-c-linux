(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Tactical

(* -------------------------------------------------------------------------- *)
(* --- Selection Composer                                                 --- *)
(* -------------------------------------------------------------------------- *)

class type composer =
  object
    method title : string
    method descr : string
    method target : selection
    method ranged : bool
    method is_valid : selection -> bool
    method get_value : selection
    method set_value : selection -> unit
  end

(* -------------------------------------------------------------------------- *)
(* --- Search                                                             --- *)
(* -------------------------------------------------------------------------- *)

class type browser =
  object
    method title : string
    method descr : string
    method target : selection
    method search : (unit named -> unit) -> int -> bool
    method choose : string option -> unit
  end

(* -------------------------------------------------------------------------- *)
(* --- Tactical Dongle                                                    --- *)
(* -------------------------------------------------------------------------- *)

class tactic : Tactical.t -> (Format.formatter -> Tactical.selection -> unit) ->
  object
    inherit Wpalette.tool
    inherit feedback
    method clear : unit
    method targeted : bool
    method select :
      process:(tactical -> selection -> process -> unit) ->
      browser:(browser -> unit) ->
      composer:(composer -> unit) ->
      tree:ProofEngine.tree ->
      selection -> unit
  end

(* -------------------------------------------------------------------------- *)
(* --- Auto Dongle                                                        --- *)
(* -------------------------------------------------------------------------- *)

type auto_callback = depth:int -> width:int -> Strategy.heuristic list -> unit

class autosearch : unit ->
  object
    inherit Wpalette.tool
    method register : Strategy.heuristic -> unit
    method connect : auto_callback option -> unit
  end

(* -------------------------------------------------------------------------- *)
(* --- Strategies Dongle                                                  --- *)
(* -------------------------------------------------------------------------- *)

type callback = (depth:int -> ProofStrategy.strategy option -> unit)

class strategies : unit ->
  object
    inherit Wpalette.tool
    method register : ProofStrategy.strategy -> unit
    method connect : ?hints:ProofStrategy.strategy list ->
      callback option -> unit
  end

(* -------------------------------------------------------------------------- *)
