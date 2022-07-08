(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

(** Cumulated Stats *)
type stats = {
  provers : (VCS.prover * pstats) list ;
  tactics : int ;
  proved : int ;
  timeout : int ;
  unknown : int ;
  noresult : int ;
  failed : int ;
  cached : int ;
}

val pp_pstats : Format.formatter -> pstats -> unit
val pp_stats : shell:bool -> updating:bool -> Format.formatter -> stats -> unit

val results : smoke:bool -> (VCS.prover * VCS.result) list -> VCS.verdict * stats
val tactical : qed:float -> stats list -> stats

val proofs : stats -> int
val complete : stats -> bool

val stats_to_json : stats -> Json.t

(* -------------------------------------------------------------------------- *)
