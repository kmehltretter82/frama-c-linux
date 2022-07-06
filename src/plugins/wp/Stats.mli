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
  time: float; (** cumulated, in seconds *)
  success: int; (** cumulated number of success *)
}

(** Cumulated Stats *)
type stats = {
  provers : (VCS.prover * pstats) list ;
  tactics : int ; (* number of tactics *)
  proved : int ;
  timeout : int ;
  unknown : int ;
  noresult : int ;
  failed : int ;
  cached : int ;
}

val pretty : Format.formatter -> stats -> unit

val results : (VCS.prover * VCS.result) list -> stats
val tactical : qed:float -> stats list -> stats

val proofs : stats -> int
val complete : stats -> bool

val to_json : stats -> Json.t

(* -------------------------------------------------------------------------- *)
