(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Handle Frama-C warnings in the GUI. *)

type t
(** Type of the widget containing the warnings. *)

val make :
  packing:(GObj.widget -> unit) ->
  callback:(Log.event -> GTree.view_column -> unit) -> t
(** Build a new widget for storing the warnings. *)

val append: t -> Log.event -> unit
(** Append a new message warning. *)

val clear: t -> unit
(** Clear all the stored warnings. *)
