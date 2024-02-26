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

open Cil_types


val nul_exp : exp

module LvalOrRef : sig
  type t = Lval of lval | Ref of lval
  val pretty : Format.formatter -> t -> unit

  (* result stored in cache. May raise Explicit_pointer_address *)
  val from_exp : exp -> t option

  (* true if x is assimilable to a pointer type (explicit pointer or
     memory adress or array *)
  val is_pointer : t -> bool
end

(* exception raised when the program tries to access a memory location directly. *)
exception Explicit_pointer_address of location

module Lval : sig
  type t = lval

  val compare: t -> t -> int

  (* result stored in cache. May raise Explicit_pointer_address *)
  val simplify : lval -> lval

  val pretty: Format.formatter -> t -> unit
end

val decompose_lval : lval -> (lval * offset) list

(** clear the two caches *)
val clear_cache : unit -> unit
