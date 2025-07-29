(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(** Handling unicode string. *)

type printer = Format.formatter -> unit

(** Set operations. *)

val pp_in_set : printer
val pp_empty_set : printer
val pp_top : printer
val pp_bottom : printer
val pp_union : printer

(* Relations. *)

val pp_le : printer
val pp_ge : printer
val pp_eq : printer
val pp_neq : printer

(* Logic operators. *)

val pp_not : printer
val pp_and : printer
val pp_or : printer
val pp_xor : printer

val pp_implies : printer
val pp_iff : printer

val pp_in_acsl : printer
val pp_forall : printer
val pp_exists : printer

(* Logic types. *)

val pp_boolean : printer
val pp_integer : printer
val pp_real : printer

(* Constants. *)

val pp_pi : printer
