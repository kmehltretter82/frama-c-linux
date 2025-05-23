(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** The Frama-C launcher.
    That is the dialog box for configuring and running Frama-C with new
    parameter values. *)

(** Subtype of {!Design.main_window_extension_points} which is required to show
    the launcher. *)
class type basic_main = object
  inherit Gtk_helper.host
  method main_window: GWindow.window
  method reset: unit -> unit
end

val show: ?height:int -> ?width:int -> host:basic_main -> unit -> unit
(** Display the Frama-C launcher. *)
