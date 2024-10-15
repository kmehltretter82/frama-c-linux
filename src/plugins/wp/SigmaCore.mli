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

(* -------------------------------------------------------------------------- *)
(* --- Uniform Sigma                                                      --- *)
(* -------------------------------------------------------------------------- *)

type sigma

include Sigs.Sigma with type t = sigma
module Chunk : Sigs.Chunk with type t = chunk

module F = Lang.F

type mu = private ..
val mu : chunk -> mu

type state = chunk F.Tmap.t
val state : sigma -> state
val apply : (F.term -> F.term) -> state -> state

module Make(C : Sigs.Chunk) :
sig
  type mu += Mu of C.t
  val chunk : C.t -> chunk
  val singleton : C.t -> domain
  val mem : sigma -> C.t -> bool
  val get : sigma -> C.t -> F.var
  val value : sigma -> C.t -> F.term
  val find : state -> F.term -> C.t
end
