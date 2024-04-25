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
(** Server API for the Interactive Prover *)
(* -------------------------------------------------------------------------- *)

module Node : Server.Data.S with type t = ProofEngine.node
module Tactic : Server.Data.S with type t = Tactical.t

val proofStatus : Server.Request.signal
val printStatus : Server.Request.signal
val selection : ProofEngine.node -> Tactical.selection
val setSelection : ProofEngine.node -> Tactical.selection -> unit

val runProvers :
  ?timeout:int ->
  ?provers:VCS.prover list ->
  ProofEngine.node -> unit

val killProvers :
  ?provers:VCS.prover list ->
  ProofEngine.node -> unit

val clearProvers :
  ?provers:VCS.prover list ->
  ProofEngine.node -> unit

(* -------------------------------------------------------------------------- *)
