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

(* -------------------------------------------------------------------------- *)
(** Interactive Proof Engine *)
(* -------------------------------------------------------------------------- *)

(** A proof tree *)
type tree

(** A proof node *)
type node

module Node :
sig
  type t = node
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val pretty : Format.formatter -> t -> unit
end

val get : Wpo.t -> [ `Script | `Proof | `Saved | `None ]
val proof : main:Wpo.t -> tree
val reset : tree -> unit
val clear : Wpo.t -> unit

(** Re-compute stats & set status of the entire script *)
val validate : tree -> unit

(** Consolidate statistics wrt current script or prover results *)
val consolidated : Wpo.t -> Stats.stats

(** Leaves are numbered from 0 to n-1 *)

type status = [
  | `Unproved (** proof obligation not proved *)
  | `Proved   (** proof obligation is proved *)
  | `Pending of int (** proof is pending *)
  | `Passed   (** smoke test is passed (PO is not proved) *)
  | `Invalid  (** smoke test has failed (PO is proved) *)
  | `StillResist of int (** proof is pending *)
]
type current = [ `Main | `Internal of node | `Leaf of int * node ]
type position = [ `Main | `Node of node | `Leaf of int ]

val pool : tree -> Lang.F.pool
val saved : tree -> bool
val set_saved : tree -> bool -> unit

val status : tree -> status
val current : tree -> current
val goto : tree -> position -> unit
val root : tree -> node
val main : tree -> Wpo.t
val goal : node -> Wpo.t
val tree : node -> tree
val head : tree -> node option
val head_goal : tree -> Wpo.t
val tree_context : tree -> WpContext.t
val node_context : node -> WpContext.t

val title : node -> string
val proved : node -> bool
val pending : node -> int
val stats : node -> Stats.stats
val depth : node -> int
val path : node -> node list
val parent : node -> node option
val tactic : node -> Tactical.t option
val child_label : node -> string option
val tactic_label : node -> string option
val subgoals : node -> node list
val children : node -> (string * node) list
val tactical : node -> ProofScript.jtactic option
val get_strategies : node -> int * Strategy.t array (* current index *)
val set_strategies : node -> ?index:int -> Strategy.t array -> unit
val get_hint : node -> string option
val set_hint : node -> string -> unit

val forward : tree -> unit
val cancel : tree -> unit
val remove : tree -> node -> unit

type fork
val anchor : tree -> ?node:node -> unit -> node
val fork : tree -> anchor:node -> ProofScript.jtactic -> Tactical.process -> fork
val iter : (Wpo.t -> unit) -> fork -> unit
val commit : fork -> node * (string * node) list
val pretty : Format.formatter -> fork -> unit

val script : tree -> ProofScript.jscript
val bind : node -> ProofScript.jscript -> unit
val bound : node -> ProofScript.jscript
