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
(** Compute the RTE table for a given file. *)

val clear : unit -> unit
(** Clear the table. *)
