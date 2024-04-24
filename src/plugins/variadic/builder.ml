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

(* A Builder.S module is a stateful module that
   1. extends Cil_builder.Stateful which already contains building utilities and
   2. stores the current state of the building process with instructions,
      variables and globals that remains to be added to the AST. It . *)

module type S =
sig
  include (module type of Cil_builder.Stateful ())

  (* The loc of the call being translated *)
  val loc : Cil_types.location

  (* These two following function stores the built global for later addition
     to the AST *)
  val finish_function : unit -> unit
  val finish_declaration : unit -> unit

  (** Start the translation of the call. Call this before declaring variables
      or inserting statements. *)
  val start_translation : unit -> unit
  (* Build a call or a Local_init with constructor depending on the currently
      translated instruction *)
  val translated_call : [< exp] -> [< exp] list -> unit
end

type t = (module S)
