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

open ProofEngine

(* -------------------------------------------------------------------------- *)
(* --- Proof Strategy Engine                                              --- *)
(* -------------------------------------------------------------------------- *)

type strategy
type alternative

val typecheck : unit -> unit

val name : strategy -> string
val find : string -> strategy option
val hints : Wpo.t -> strategy list
val has_hint : Wpo.t -> bool

val alternatives : strategy -> alternative list
val provers : alternative -> VCS.prover list * float
val auto : alternative -> Strategy.heuristic option
val fallback : alternative -> strategy option
val tactic : tree -> node -> strategy -> alternative -> node list option

(* -------------------------------------------------------------------------- *)
