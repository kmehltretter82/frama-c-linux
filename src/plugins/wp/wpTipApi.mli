(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
  ?mode:VCS.mode ->
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
