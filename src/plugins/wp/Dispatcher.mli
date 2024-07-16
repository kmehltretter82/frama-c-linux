(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

open Either
open Lang.F
open Ctypes
open Cil_types
open Interpreted_automata
open Sigs


val partition: ('a -> ('b, 'c) Either.t) -> 'a list -> 'a list * 'a list
val split    : ('a, 'b) Either.t list -> 'a list * 'b list

module type Dispatcher =
sig

  type loc_left
  type loc_right

  module ML : Sigs.Model with type loc = loc_left
  module MR : Sigs.Model with type loc = loc_right

  type loc = (loc_left, loc_right) t

  val null : loc
  val is_null : loc -> pred
  val cvar : varinfo -> loc
  val pointer_loc : QED.term -> loc
  val loc_of_int : c_object -> QED.term -> loc

  val deref_left  : loc_left  -> loc_left  -> loc
  val deref_right : loc_right -> loc_right -> loc
  val literal : eid:int -> Cstring.cst -> loc


  (* utilities *)
  val hypotheses : MemoryContext.partition -> MemoryContext.partition
  val configure_ia: automaton -> vertex binder

end

(* module Make (_: Sigs.Model) (_: Sigs.Model) : Dispatcher *)
