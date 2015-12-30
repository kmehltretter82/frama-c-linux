(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2015                                               *)
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

open Cil_types

(******************************************************************************)
(** {2 Typing} *)
(******************************************************************************)

type integer_ty =
  | Gmp
  | C_type of ikind

val type_named_predicate: ?must_clear:bool -> predicate named -> unit
(** Compute the type of each term of the given predicate. *)

val typ_of_term: term -> typ
(** Get the type of the given term. {!type_named_predicate} must already have
    been called on the englobing predicate. *)

val cast_of_term: term -> typ option
(** Get the type which the given term must be converted to after its translation
    (if any). {!type_named_predicate} must already have been called on the
    englobing predicate. *)

val clear: unit -> unit
(** Remove all the previously computed types. *)

(******************************************************************************)
(** {2 Other typing-related functions} *)
(******************************************************************************)

val is_representable: Integer.t -> ikind -> bool
(** Is the given constant representable in the given kind? *)

(******************************************************************************)
(** {2 Internal stuff} *)
(******************************************************************************)

val compute_quantif_guards_ref
    : (predicate named -> logic_var list -> predicate named ->
       (term * relation * logic_var * relation * term) list) ref
(** Forward reference. *)

(*
Local Variables:
compile-command: "make"
End:
*)
