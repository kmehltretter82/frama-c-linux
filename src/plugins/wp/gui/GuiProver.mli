(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Widget

val no_status : icon
val ok_status : icon
val ko_status : icon
val wg_status : icon
val smoke_status : icon

val filter : VCS.prover -> bool

(** Requires [filter prover]. *)
class prover : console:Wtext.text -> prover:VCS.prover ->
  object
    inherit Wpalette.tool
    method clear : unit
    method update : Wpo.t -> unit
    method prover : VCS.prover
  end
