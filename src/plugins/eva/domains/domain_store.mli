(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Eval

module type InputDomain = sig
  include Datatype.S

  (* The domain name, shown in some logs and in the GUI. *)
  val name: string

  val top: t
  val join: t -> t -> t
end

(** Automatic storage of the states computed during the analysis. *)
module type S = sig
  type t

  (** Called once at the analysis beginning for the entry state of the main
      function. The boolean indicates whether the states of this domain must be
      saved during the analysis, according to options -eva-no-results. If it is
      false, register functions do nothing, and get functions return Top. *)
  val register_global_state: bool -> t or_bottom -> unit

  val register_initial_state: Callstack.t -> kernel_function -> t -> unit
  val register_state_before_stmt: Callstack.t -> stmt -> t -> unit
  val register_state_after_stmt: Callstack.t -> stmt -> t -> unit

  (** Allows accessing the states inferred by an Eva analysis after it has
      been computed with the domain enabled. *)
  val get_global_state: unit -> t or_bottom
  val get_initial_state: kernel_function -> t or_bottom
  val get_initial_state_by_callstack:
    ?selection:Callstack.t list ->
    kernel_function -> t Callstack.Hashtbl.t or_top_bottom

  val get_stmt_state: after:bool -> stmt -> t or_bottom
  val get_stmt_state_by_callstack:
    ?selection:Callstack.t list ->
    after:bool -> stmt -> t Callstack.Hashtbl.t or_top_bottom

  val mark_as_computed: unit -> unit
  val is_computed: unit -> bool
end

module Make (Domain : InputDomain) : S with type t := Domain.t
