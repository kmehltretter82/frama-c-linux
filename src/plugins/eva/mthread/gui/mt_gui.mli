(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type ui = Design.main_window_extension_points

(** Registers a hook called when the user selects a thread in the menu. *)
val register_thread_hook: (ui -> Mt_thread.thread_state -> unit) -> unit
