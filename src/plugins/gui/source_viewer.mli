(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** The Frama-C source viewer.
    That is the buffer where Frama-C puts its pretty-printed AST. *)

val make : ?name:string -> packing:(GObj.widget -> unit) -> unit ->
  GSourceView.source_view
(** Build a new source viewer. *)

val buffer : unit -> GSourceView.source_buffer
(** @return the buffer displaying the pretty-printed AST. *)
