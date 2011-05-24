(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2010                                               *)
(*    CEA (Commissariat à l'Énergie Atomique)                             *)
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

(** Utilities for E-ACSL. *)

open Cil_types
open Cil_datatype

(* ************************************************************************** *)
(** {2 Handling errors} *)
(* ************************************************************************** *)

exception Typing_error of string
val type_error: string -> 'a
(** @raise Typing_error with  with a message built from the given one. *)

val not_yet: string -> 'a
(** @raise Log.FeatureRequest with a message built from the given one. *)

(* ************************************************************************** *)
(** {2 Builders} *)
(* ************************************************************************** *)

val new_lval: ?loc:Location.t -> varinfo -> exp
(* [TODO] put it in the Frama-C kernel? *)

val mk_call: ?loc:Location.t -> ?result:lval -> string -> exp list -> stmt
val mk_e_acsl_guard: ?reverse:bool -> exp -> predicate named -> stmt
val e_acsl_header: unit -> global

(*
Local Variables:
compile-command: "make"
End:
*)
