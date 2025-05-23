(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Helper module to register read and written memory zones to {!Inout_access}
    in {!Transfer_stmt} and {!Transfer_specification} *)

module type S = sig
  type location
  type value
  type valuation

  (** [register_logc_assign pos clause location] registers to [Inout_access]
      the read and written memory zones at [pos] for the logic assign [clause]
      to the [location]. The memory accessed by the logic assign is returned. *)
  val register_logic_assign :
    Position.t -> location Eval.logic_assign -> location ->
    Inout_access.t

  (** [register_assign_lval pos valuation lval exp] registers to [Inout_access]
      the read and written memory zones at [pos] for the assignment from [exp]
      to [lval] with a given [valuation]. The memory accessed by the assignment
      is returned. *)
  val register_assign_lval :
    Position.t -> valuation ->
    Eva_ast.lval -> Eva_ast.exp ->
    Inout_access.t

  (** [register_assign_var pos valuation vi exp] registers to [Inout_access]
      the read and written memory zones at [pos] for the assignment from [exp]
      to [vi] with a given [valuation]. The memory accessed by the assignment is
      returned. *)
  val register_assign_var :
    Position.t -> valuation ->
    Eva_ast.varinfo -> Eva_ast.exp ->
    Inout_access.t

  (** [register_read_exp pos valuation exp] registers to [Inout_access] the
      read memory zones at [pos] for reading the expression [exp] with a given
      [valuation]. The memory accessed by the read is returned. *)
  val register_read_exp :
    Position.t -> valuation ->
    Eva_ast.exp ->
    Inout_access.t

  (** [register_call_args pos valuation call] registers to [Inout_access] the
      read and written memory zones at [pos] for the arguments of the given
      [call] with a given [valuation]. The memory accessed by the call arguments
      is returned. *)
  val register_call_args :
    Position.t -> valuation ->
    (location, value) Eval.call ->
    Inout_access.t
end

module Make (Engine : Engine_sig.S)
  : S with type location = Engine.Loc.location
       and type value = Engine.Val.t
       and type valuation = Engine.Eval.Valuation.t
