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
(** {1 Performance Reporting} *)
(* -------------------------------------------------------------------------- *)

(** Prover Stats *)
type pstats = {
  tmin : float ; (** minimum prover time (non-smoke proof only) *)
  tval : float ; (** cummulated prover time (non-smoke proof only) *)
  tmax : float ; (** maximum prover time (non-smoke proof only) *)
  tnbr : float ; (** number of non-smoke proofs *)
  time : float ; (** cumulated prover time (smoke and non-smoke) *)
  success : float ; (** number of success (valid xor smoke) *)
}

(** Cumulated Stats

    Remark: for each sub-goal, only the _best_ prover result is kept *)
type stats = {
  best : VCS.verdict ; (** provers best verdict (not verdict of the goal) *)
  provers : (VCS.prover * pstats) list ; (** meaningfull provers *)
  tactics : int ; (** number of tactics *)
  proved : int ; (** number of proved sub-goals *)
  timeout : int ; (** number of timeouts and stepouts sub-goals *)
  unknown : int ; (** number of unknown sub-goals *)
  noresult : int ; (** number of no-result sub-goals *)
  failed : int ; (** number of failed sub-goals *)
  cached : int ; (** number of cached prover results *)
  cacheable : int ; (** number of prover results that can be cached *)
}

val pp_pstats : Format.formatter -> pstats -> unit
val pp_stats :
  shell:bool ->
  cache:Cache.mode ->
  Format.formatter -> stats -> unit

val pretty : Format.formatter -> stats -> unit

val empty : stats
val add : stats -> stats -> stats

val results : smoke:bool -> (VCS.prover * VCS.result) list -> stats
val tactical : qed:float -> stats list -> stats
val script : stats -> VCS.result

val subgoals : stats -> int
(* sum of proved + timeout + unit + noresult + failed *)

val complete : stats -> bool

(* -------------------------------------------------------------------------- *)
