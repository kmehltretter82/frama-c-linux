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

exception Not_representable
val typ_of_integer: My_bigint.t -> bool -> ikind
(** Compute the best type of a bigint. The boolean must be [true] for unsigned
    and [false] for signed.
    @raise Not_representable if the integer does not fit in any C type. *)

val type_named_predicate: predicate named -> unit
(** Compute the type of each term of the given predicate. *)

val type_term: term -> unit
(** Compute the type of the given term. *)

val typ_of_term: term -> typ
(** Get the type of the given term. Must have been previously computed. *)

val unsafe_set_term: term -> typ -> unit
(** Modify the type of the given term. No verification is done to check that the
    new type is correct. *)

val clear: unit -> unit
(** Remove all the previously computed types. *)

(******************************************************************************)
(** {2 Subtyping} *)
(******************************************************************************)

val principal_type: term -> term -> typ
(** Get the principal type of the two given terms, that is the type which may
    contain both of them. Their types must have been previously computed. *)

val context_sensitive: 
  ?loc:location -> ?name:string -> 
  Env.t -> typ -> bool -> term option -> exp -> exp * Env.t
(** [context_sensitive env ty is_mpz_string t_opt e] converts [e] in [env] in
    such a way that it becomes usable in a context of type [ty]. [t_opt], if
    any, is a term denoting by [e]. [is_mpz_string] is [true] iff [e] is a
    string denoting a MPZ integer. *)

val is_representable: My_bigint.t -> ikind -> bool
(** Is the given constant representable? *)

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
