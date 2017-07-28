(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2016                                               *)
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
(*  for more details (enclosed in the file license/LGPLv2.1).             *)
(*                                                                        *)
(**************************************************************************)

(** Transformations to detect temporal memory errors (e.g., derererence of
    stale pointers). Detailed description of the transformations is presented
    in Sections 2 and 3 of the RV'17 paper "Runtime Detection of Temporal Memory
    Errors" by K. Vorobyov, N. Kosmatov, J Signoles and A. Jakobsson.
*)

val enable: bool -> unit
(** Enable/disable temporal transformations *)

val is_enabled: unit -> bool
(** Return a boolean value indicating whether temporal analysis is enabled *)

val handle_arguments: Cil_types.kernel_function -> Env.t -> Env.t
(** Update local environment ([Env.t]) with statements allowing to track
    referent numbers across calls function whose definitions are available.
    This is such that whenever a function [f] is called (and a new stack
    frame is created) [handle_arguments] generates statements that transfer
    referent numbers stored in RTL to the new stack frame. *)

val handle_stmt: Cil_types.stmt -> Env.t -> Env.t
(** Update local environment ([Env.t]) with statements tracking temporal
    properties of memory blocks *)

val handle_global_init: Cil_types.varinfo -> Cil_types.offset ->
  Cil_types.init -> Env.t -> Cil_types.stmt option
  (** Generate [Some s], where [s] is a statement tracking global initializer
      or [None] if there is no need to track it *)
