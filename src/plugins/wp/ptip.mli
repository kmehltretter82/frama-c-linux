(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

open Conditions
module F = Lang.F
module Env = Plang.Env

type 'a printer = Format.formatter -> 'a -> unit

(* -------------------------------------------------------------------------- *)
(* --- Autofocus                                                          --- *)
(* -------------------------------------------------------------------------- *)

type v_fold = [ `Auto | `Visible | `Hidden ]
type v_term = [ v_fold | `Shared | `Name of string ]

type part = Term | Goal | Step of step

class autofocus :
  object
    method clear : unit
    method reset : unit
    method env : Env.t
    method set_term : F.term -> v_term -> unit
    method get_term : F.term -> v_term
    method set_target : F.term -> unit
    method clear_target : unit
    method focus : extend:bool -> F.term -> unit
    method unfocus : F.term -> unit
    method unfocus_last : unit
    method is_selected : F.term -> bool
    method is_focused : F.term -> bool
    method is_visible : F.term -> bool
    method is_targeted : F.term -> bool
    method set_autofocus : bool -> unit
    method get_autofocus : bool
    method is_autofocused : bool
    method set_step : step -> v_fold -> unit
    method get_step : step -> v_fold
    method is_visible_step : step -> bool
    method locate : F.term -> Tactical.selection
    method set_sequent : sequent -> bool
  end

(* -------------------------------------------------------------------------- *)
(* --- Term Engine                                                        --- *)
(* -------------------------------------------------------------------------- *)

class type term_wraper =
  object
    method wrap : F.term printer -> F.term printer
  end

class type term_selection =
  object
    method is_focused : F.term -> bool
    method is_visible : F.term -> bool
    method is_targeted : F.term -> bool
  end

class plang :
    terms:#term_wraper ->
    focus:#term_wraper ->
    target:#term_wraper ->
    autofocus:#term_selection ->
    object
      inherit Pcond.state
      method set_target : F.term -> unit
      method clear_target : unit
    end

(* -------------------------------------------------------------------------- *)
(* --- Sequent Engine                                                     --- *)
(* -------------------------------------------------------------------------- *)

class type part_marker =
  object
    method wrap : part printer -> part printer
    method mark : 'a. part -> 'a printer -> 'a printer
  end

class type step_selection =
  object
    method is_visible : F.term -> bool
    method is_visible_step : step -> bool
  end

class pcond :
    parts:#part_marker ->
    target:#part_marker ->
    autofocus:#step_selection ->
    plang:#Pcond.state ->
  object
    inherit Pcond.seqengine
    method visible : step -> bool
    method set_target : part -> unit
  end

(* -------------------------------------------------------------------------- *)
