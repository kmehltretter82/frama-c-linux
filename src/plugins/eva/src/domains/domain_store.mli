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

  (** The domain name, used to enable it via -eva-domains. *)
  val name: string

  (** The state representing all possible concrete states. Returned when the
      analysis has not started, or states have not been saved. *)
  val top: t
end

(** Automatic storage of the states computed during the analysis. *)
module type S = sig
  type t

  (** Registers the state computed after the initialization of global variables.
      Called only once at the start of the analysis. *)
  val set_global_state: t -> unit

  (** Registers the initial state for the given function:
      - for the given [callstack] if provided;
      - for any callstack otherwise. *)
  val set_initial_state: ?callstack:Callstack.t -> kernel_function -> t -> unit

  (** Registers the state computed before or after a statement:
      - for the given [callstack] if provided;
      - for any callstack otherwise. *)
  val set_stmt_state: ?callstack:Callstack.t -> after:bool -> stmt -> t -> unit

  (** Functions [get_*] below return:
      - [Domains.top] if no analysis has started or if states are not stored.
      - otherwise, the state set by the last call to the corresponding [set]
        function above with the same arguments.
      - [`Bottom] if no such call has been made. *)

  (** Returns the last state set by [set_global_state], if any.*)
  val get_global_state: unit -> t or_bottom

  (** Returns the last state set by [set_initial_state] for the given function
      and callstack (if provided). *)
  val get_initial_state: ?callstack:Callstack.t -> kernel_function -> t or_bottom

  (** Returns the last state set by [set_stmt_state] for the given statement
      and callstack (if provided). *)
  val get_stmt_state: ?callstack:Callstack.t -> after:bool -> stmt -> t or_bottom

  (** Returns all callstacks from previous calls to [set_initial_state] for the
      given function. *)
  val kf_callstacks: kernel_function -> Callstack.t Seq.t or_top

  (** Returns all callstacks from previous calls to [set_stmt_state ~after:false]
      for the given statement. *)
  val stmt_callstacks: stmt -> Callstack.t Seq.t or_top

  (** Are states of this domain saved? *)
  val is_enabled: unit -> bool
end

module Make (Domain : InputDomain) : S with type t := Domain.t
