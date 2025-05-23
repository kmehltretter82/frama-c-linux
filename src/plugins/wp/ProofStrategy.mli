(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
val loc : strategy -> Cil_types.location
val find : string -> strategy option
val hints : ?node:ProofEngine.node -> Wpo.t -> strategy list
val has_hint : Wpo.t -> bool

val iter : (strategy -> unit) -> unit
val default : unit -> strategy list
val alternatives : strategy -> alternative list
val provers : ?default:VCS.prover list -> alternative -> VCS.prover list * float
val auto : alternative -> Strategy.heuristic option
val fallback : alternative -> strategy option
val tactic : tree -> node -> strategy -> alternative -> node list option

val pp_strategy : Format.formatter -> strategy -> unit
val pp_alternative : Format.formatter -> alternative -> unit

(* -------------------------------------------------------------------------- *)
