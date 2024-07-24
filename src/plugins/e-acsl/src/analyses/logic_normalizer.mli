(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2024                                               *)
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

(** This module is dedicated to some preprocessing on the predicates:
    - It guards all the [Pvalid] and [Pvalid_read] clauses with
      an adequate [Pinitialized] clause;
    - It replaces all the applications [Papp] by a corresponding
      term obtained as an application [Tapp]
      The predicates that have undergone these changed are
      called the preprocessed predicates.
*)

open Cil_types

val preprocess : file -> unit
(** Preprocess all the predicates of the ast and store the results *)

val preprocess_annot : code_annotation -> unit
(** Preprocess of the predicate of a single code annotation and store
    the results *)

val preprocess_predicate : predicate -> unit
(** Preprocess a predicate and its children and store the results  *)

(** The analyses in [Logic_normalizer] may:
    - create new auxiliary predicates and logic functions
    - transform inductively and axiomatically defined logic functions and
      predicates into recursively defined ones
      This module provides functions to inquire about their status. *)
module Logic_infos : sig
  val generated_of : logic_info -> logic_info list
  (** auxiliary [logic_info]s generated from the given [logic_info]. *)

  val origin_of_lv : logic_var -> logic_var
  (** Identify the [logic_info] from which the [logic_info] identified by the
      given argument stems from. This is required in order to create meaningful
      feedback messages for the user who should not be confronted with the
      names of generated logic functions. *)
end

val get_pred : predicate -> predicate
(** Retrieve the preprocessed form of a predicate *)

val get_orig_pred : predicate -> predicate
(** Retrieve the original form of the given predicate *)

val get_term : term -> term
(** Retrieve the preprocessed form of a term *)

val get_orig_term : term -> term
(** Retrieve the original form of the given term *)

val clear: unit -> unit
(** clear the table of normalized predicates *)
