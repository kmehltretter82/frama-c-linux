(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(** Why3 (and provers) configuration *)
(* -------------------------------------------------------------------------- *)

(** {2 Why3 configuration } *)

val why3_version : string
val env : unit -> Why3.Env.env
val config : unit -> Why3.Whyconf.config
val configure : unit -> unit
val set_procs : int -> unit

(** {2 Prover information } *)

type prover = Why3.Whyconf.prover

val ident_why3 : prover -> string
val ident_wp : prover -> string
val title : ?version:bool -> prover -> string
val name : prover -> string
val version : prover -> string
val compare : prover -> prover -> int
val equal : prover -> prover -> bool
val hash : prover -> int

val lookup : ?fallback:bool -> string -> prover option
val provers : unit -> prover list
val is_auto : prover -> bool
val is_available : prover -> bool
val is_mainstream : prover -> bool
val has_counter_examples : prover -> bool
val with_counter_examples : prover -> prover option

type model = Why3.Model_parser.concrete_syntax_term
val pp_model : model Pretty_utils.formatter

(**************************************************************************)
