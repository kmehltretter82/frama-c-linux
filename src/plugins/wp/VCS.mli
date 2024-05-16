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
(** Verification Condition Status *)
(* -------------------------------------------------------------------------- *)

(** {2 Prover} *)

type prover =
  | Why3 of Why3Provers.t (** Prover via WHY *)
  | Qed           (** Qed Solver *)
  | Tactical      (** Interactive Prover *)

type mode =
  | Batch  (** Only check scripts *)
  | Update (** Check and update scripts *)
  | Edit   (** Edit then check scripts *)
  | Fix    (** Try check script, then edit script on non-success *)
  | FixUpdate (** Update & Fix *)

module Pset : Set.S with type elt = prover
module Pmap : Map.S with type key = prover

(** Mainstream installed provers *)
val provers : unit -> prover list

val name_of_prover : prover -> string
val title_of_prover : ?version:bool -> prover -> string
val filename_for_prover : prover -> string
val title_of_mode : mode -> string

val parse_mode : string -> mode

(** For the command line *)
val parse_prover : string -> prover option

(** For scripts *)
val prover_of_name : ?fallback:bool -> string -> prover option

val pp_prover : Format.formatter -> prover -> unit
val pp_mode : Format.formatter -> mode -> unit

val eq_prover : prover -> prover -> bool
val cmp_prover : prover -> prover -> int

(* -------------------------------------------------------------------------- *)
(** {2 Config}
    [None] means current WP option default.
    [Some 0] means prover default. *)
(* -------------------------------------------------------------------------- *)

type config = {
  valid : bool ;
  timeout : float option ;
  stepout : int option ;
  memlimit : int option ;
}

val current : unit -> config (** Current parameters *)

val default : config (** all None *)

val get_timeout : ?kf:Kernel_function.t -> smoke:bool -> config -> float
(** 0.0 means no-timeout *)

val get_stepout : config -> int
(** 0 means no-stepout *)

val get_memlimit : config -> int
(** 0 means no-memlimit *)

(** {2 Results} *)

type verdict =
  | NoResult
  | Unknown
  | Timeout
  | Stepout
  | Computing of (unit -> unit) (* kill function *)
  | Valid
  | Invalid (* model *)
  | Failed

type model = Why3Provers.model Probe.Map.t

type result = {
  verdict : verdict ;
  cached : bool ;
  solver_time : float ;
  prover_time : float ;
  prover_steps : int ;
  prover_errpos : Lexing.position option ;
  prover_errmsg : string ;
  prover_model : model ;
}

val no_result : result
val valid : result
val unknown : result
val stepout : int -> result
val timeout : float -> result
val computing : (unit -> unit) -> result
val failed : ?pos:Lexing.position -> string -> result
val kfailed : ?pos:Lexing.position -> ('a,Format.formatter,unit,result) format4 -> 'a
val cached : result -> result (** only for true verdicts *)

val result : ?model:model -> ?cached:bool ->
  ?solver:float -> ?time:float -> ?steps:int -> verdict -> result

val is_auto : prover -> bool
val has_counter_examples : prover -> bool
val is_prover : prover -> bool
val is_extern : prover -> bool

val is_result : verdict -> bool
val is_proved: smoke:bool -> verdict -> bool

val is_none : result -> bool
val is_verdict : result -> bool
val is_valid: result -> bool
val is_trivial: result -> bool
val is_not_valid: result -> bool
val is_computing: result -> bool
val has_model: result -> bool

val configure : result -> config
val autofit : result -> bool (** Result that fits the default configuration *)

val name_of_verdict : ?computing:bool -> verdict -> string

val pp_result : Format.formatter -> result -> unit
val pp_model : Format.formatter -> model -> unit
val pp_result_qualif : ?updating:bool -> prover -> result ->
  Format.formatter -> unit

val conjunction : verdict -> verdict -> verdict (* for tactic children *)
val compare : result -> result -> int (* minimal is best *)
val best : (prover * result) list -> prover * result

val dkey_shell: Wp_parameters.category
