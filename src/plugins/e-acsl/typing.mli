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

(** Type system which computes the smallest C type that may contain all the
    possible values of a given integer term or predicate. Also compute the
    required casts. *)

open Cil_types

(******************************************************************************)
(** {2 Datatypes} *)
(******************************************************************************)

(** Types infered by the system. *)
type integer_ty = private
  | Gmp
  | C_type of ikind
  | Other (** Any non-integral type *)

(** {3 Smart constructors} *)

val gmp: integer_ty
val c_int: integer_ty
val ikind: ikind -> integer_ty

(** {3 Useful operations over {!integer_ty} *)

exception Not_an_integer
val typ_of_integer_ty: integer_ty -> typ
(** @return the smallest C type corresponding to an {!integer_ty}.
    @raise Not_an_integer in case of {!Other}. *)

val join: integer_ty -> integer_ty -> integer_ty
(** {!integer_ty} is almost a join-semi-lattice: assume that if one argument is
    {!Other}, then the second argument is also {!Other}. *)

(******************************************************************************)
(** {2 Typing} *)
(******************************************************************************)

val type_term: force:bool -> ctx:integer_ty -> term -> unit
(** Compute the type of each subterm of the given term in the given context. If
    [force] is true, then the conversion to the given context is done even if
    -e-acsl-gmp-only is set. *)

val type_named_predicate: ?must_clear:bool -> predicate named -> unit
(** Compute the type of each term of the given predicate.
    Set {!must_clear} to false in order to not reset the environment. *)

val clear: unit -> unit
(** Remove all the previously computed types. *)

(** {3 Getters}

    Below, the functions assume that either {!type_term} or
    {!type_named_predicate} has been previously computed for the given term or
    predicate. *)

val get_integer_ty: term -> integer_ty
(** @return the infered type for the given term. *)

val get_integer_op: term -> integer_ty
(** @return the infered type for the top operation of the given term.
    It is meaningless to call this function over a non-arithmetical/logical
    operator. *)

val get_integer_op_of_predicate: predicate named -> integer_ty
(** @return the infered type for the top operation of the given predicate. *)

val get_typ: term -> typ
(** Get the type which the given term must be generated to. *)

val get_op: term -> typ
(** Get the type which the operation on top of the given term must be generated
    to. *)

val get_cast: term -> typ option
(** Get the type which the given term must be converted to (if any). *)

val get_cast_of_predicate: predicate named -> typ option
(** Like {!get_cast}, but for predicates. *)

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
