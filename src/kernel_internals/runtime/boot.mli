(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(** Frama-C main interface.
    @since Lithium-20081201
    @before 29.0-Copper it was in a module named Db
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)
module Main : sig
  val extend : (unit -> unit) -> unit
  (** Register a function to be called by the Frama-C main entry point.
      @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)
end

val play_analysis : unit -> unit
(** Run all the Frama-C analyses. This function should be called only by
    toplevels.
    @since 29.0-Copper
*)

val boot : unit -> unit
(** Start and define the Frama-C kernel main loop. *)

val set_toplevel: ((unit -> unit) -> unit) -> unit
(** Changes the toplevel function to run on boot
    @since 29.0-Copper
    @before 29.0-Copper it was provided in a different way in Db.Toplevel
*)
