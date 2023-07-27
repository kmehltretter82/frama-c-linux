(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
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

(* This module is out of place but is kept here for simplicity. *)
module Thread :
sig
  type t

  val main: unit -> t

  val spawn:
    Cvalue.V.t ->
    Cil_types.stmt ->
    Cil_types.kernel_function ->
    Cvalue.V.t list -> t

  val set_current: t -> unit
end

type 'a domain = (module Abstract.Domain.External with type state = 'a)
type analysis_location = Callstack.t * Cil_types.stmt
type thread_id = int
type t

module AnalysisLocation : Datatype.S_with_collections
  with type t = analysis_location

(* Current interferences, set by Mthread *)
val current : t ref

val initial : 'a domain -> t

val add_last_analysis :
  domain:'a domain ->
  get_state:(analysis_location -> 'a Lattice_bounds.or_top_bottom) ->
  t -> Thread.t -> analysis_location list -> Base.Hptset.t -> unit

val inject : domain:'a domain -> t -> 'a -> 'a
