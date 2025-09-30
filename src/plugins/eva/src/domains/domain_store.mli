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
end

(** Automatic storage of the states computed during the analysis. *)
module type S = sig
  type t

  (** Called once at the analysis beginning for the entry state of the main
      function. The boolean indicates whether the states of this domain must be
      saved during the analysis, according to options -eva-no-results. If it is
      false, all set functions do nothing, and get functions return Top. *)
  val set_global_state: bool -> t or_bottom -> unit

  val set_initial_state: ?callstack:Callstack.t -> kernel_function -> t -> unit
  val set_stmt_state: ?callstack:Callstack.t -> after:bool -> stmt -> t -> unit

  (** Allows accessing the states inferred by an Eva analysis after it has
      been computed with the domain enabled. *)

  val get_global_state: unit -> t or_bottom
  val get_initial_state: ?callstack:Callstack.t -> kernel_function -> t or_bottom
  val get_stmt_state: ?callstack:Callstack.t -> after:bool -> stmt -> t or_bottom

  val kf_callstacks: kernel_function -> Callstack.t Seq.t or_top
  val stmt_callstacks: stmt -> Callstack.t Seq.t or_top

  val is_enabled: unit -> bool
end

module Make (Domain : InputDomain) : S with type t := Domain.t
