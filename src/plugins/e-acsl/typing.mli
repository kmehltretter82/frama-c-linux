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

open Cil_types

(******************************************************************************)
(** {2 Typing} *)
(******************************************************************************)

val typ_of_term: term -> typ
val type_named_predicate: predicate named -> unit
val type_term: term -> unit
val unsafe_set_term: term -> typ -> unit
val clear: unit -> unit

(******************************************************************************)
(** {2 Subtyping} *)
(******************************************************************************)

val principal_type: term -> term -> typ

val context_sensitive: 
  ?loc:location -> Env.t -> typ -> bool -> term option -> exp -> 
  exp * Env.t

val is_representable: My_bigint.t -> ikind -> string option -> bool
(** Is the given constant representable?
    (See [Cil_types.CInt64] for details about arguments *)

(******************************************************************************)
(** {2 Internal stuff} *)
(******************************************************************************)

val compute_quantif_guards_ref
    : (predicate named -> logic_var list -> predicate named -> 
       (term * relation * logic_var * relation * term) list) ref

(*
Local Variables:
compile-command: "make"
End:
*)
