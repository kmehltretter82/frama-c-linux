(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type t =
  | Why3 of Why3Provers.t (** Prover via WHY *)
  | Qed                   (** Qed Solver *)
  | Tactical              (** Interactive Prover *)

module Pset : Set.S with type elt = t
module Pmap : Map.S with type key = t

(** Mainstream installed provers *)
val provers : unit -> t list
val iter_provers : (t -> unit) -> unit

val equal : t -> t -> bool
val compare : t -> t -> int
val pretty : Format.formatter -> t -> unit

val ident : t -> string
(** Identifier of the Prover for WP, typically "CVC5:1.2.1" *)

val name : t -> string
(** Name of the prover, typically CVC5 *)

val shortcut : t -> string
(** Shortcut name (typically lowercase name) *)

val version : t -> string
(** Frama-C version for TIP and Qed *)

val title : ?version:bool -> t -> string


val parse : string -> t option

val is_auto : t -> bool
val is_tactical : t -> bool
val is_extern : t -> bool
val has_counter_examples : t -> bool

val filename_for : t -> string
val of_name : ?fallback:bool -> string -> t option

module InteractiveMode : sig
  type t =
    | Batch  (** Only check scripts *)
    | Update (** Check and update scripts *)
    | Edit   (** Edit then check scripts *)
    | Fix    (** Try check script, then edit script on non-success *)
    | FixUpdate (** Update & Fix *)

  val title : t -> string
  val parse : string -> t
  val pretty : Format.formatter -> t -> unit
end

module TipMode : sig
  type t =
    | Batch
    | Update
    | Dry
    | Init

  val get : unit -> t
  val set : t -> unit

  val is_scratch: unit -> bool
  val is_saving: unit -> bool
end

val dkey_shell : Wp_parameters.category
