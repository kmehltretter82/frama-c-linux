(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Eval

val current_kf_inout: unit -> Inout_type.t option

module type S = sig

  type state
  type value
  type loc

  val assign: pos:Position.t -> state -> lval -> exp -> state or_bottom

  val assume: pos:Position.t -> state -> exp -> bool -> state or_bottom

  val call:
    pos:Position.local ->
    lval option -> lhost -> exp list -> state -> state Engine_sig.call_result

  val check_unspecified_sequence:
    pos:Position.t ->
    state ->
    (* TODO *)
    (stmt * lval list * lval list * lval list * stmt ref list) list ->
    unit or_bottom

  val enter_scope: pos:Position.t -> varinfo list -> state -> state
end

module Make (Abstract: Engine_sig.S)
  : S with type state = Abstract.Dom.t
       and type value = Abstract.Val.t
       and type loc = Abstract.Loc.location
