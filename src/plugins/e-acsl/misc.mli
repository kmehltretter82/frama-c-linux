(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012                                                    *)
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

(** Utilities for E-ACSL. *)

open Cil_types
open Cil_datatype

(* ************************************************************************** *)
(** {2 Builders} *)
(* ************************************************************************** *)

val new_lval: ?loc:Location.t -> varinfo -> exp
(* [TODO] put it in the Frama-C kernel? *)

val mk_call: ?loc:Location.t -> ?result:lval -> string -> exp list -> stmt

type annotation_kind = Assertion | Precondition | Postcondition | Invariant

val mk_e_acsl_guard: 
  ?reverse:bool -> annotation_kind -> exp -> predicate named -> stmt

val e_acsl_header: unit -> global

(*
Local Variables:
compile-command: "make"
End:
*)
