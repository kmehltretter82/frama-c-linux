(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

val dkey : Options.category

val preprocess : file -> unit
(** compute the RTE table for a given file. *)

val preprocess_predicate : predicate -> unit
(** compute the RTE table for a given predicate. *)

val iter_on_guards : term -> (predicate -> unit) -> unit
(** retrieve the list of guards for a given term and, if it exists, iterate over
    all elements applying a given function to them. *)

val fold_guards : default:'a -> term -> (predicate -> 'a -> 'a) -> 'a
(* retrieve the list of guards for a given term, if it exists, and apply folding
   operation to it using a given function. *)

val remove : term -> unit
(** remove an entry from the table. *)

val clear : unit -> unit
(** clear the table. *)
