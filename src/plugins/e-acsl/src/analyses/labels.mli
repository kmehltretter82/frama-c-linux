(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2021                                               *)
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

(** Labeled term and predicates pre-analysis *)

open Cil_types
open Analyses_types

val get_first_inner_stmt: stmt -> stmt
(** If the given statement has a label, return the first statement of the block.
    Otherwise return the given statement. *)

(** Manage labeled terms and predicates translation *)
module Translation : sig
  (** Represents a labeled translation *)
  type t =
    | Done of exp
    (** The translation is done and the result is the expression [e] *)
    | Queued
    (** The translation needs to be done in a statement preceding the statement
        where the labeled term or predicate is used. *)
    | Inplace
    (** The translation can be done when translating the statement where the
        labeled term or predicate is used. *)

  val at_for_stmt: stmt -> at_data list Error.result
  (** @return the list of labeled predicates and terms to be translated on the
      given statement. *)

  val set: ?force:bool -> at_data -> t Error.result -> unit
  (** Sets the translation for the given labeled term or predicate.

      If a translation already exists, then the behavior depend on the existing
      translation and the new translation:
      - If the new translation is an error, keep the old translation except if
        [force] is true;
      - If the existing translation is an error and the new translation is a result,
        always keep the new translation;
      - If both translation are results:
        -- if the old is Queued and the new one is Queued or Done, then keep the
           new one;
        -- if one is Queued and the other is Inplace, then store Queued;
        -- if both are Inplace then keep Inplace
        -- other combinations are errors. *)

  val get: at_data -> t Error.result
  (** @return the translation for the given labeled term or predicate. *)
end

val preprocess: file -> unit
(** Analyse sources to find the statements where a labeled predicate or term
    should be translated. *)

val reset: unit -> unit
(** Reset the results of the pre-anlaysis. *)

val pp_at_data: Format.formatter -> at_data -> unit
(** Printer for [at_data]. *)

val _debug: unit -> unit
(** Print internal state of labels translation. *)

(**************************************************************************)
(********************** Forward references ********************************)
(**************************************************************************)

val must_translate_ppt_ref: (Property.t -> bool) ref

val must_translate_ppt_opt_ref: (Property.t option -> bool) ref

val has_empty_quantif_ref: ((term * logic_var * term) list -> bool) ref

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
