(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of the GUI in order to display red alarms emitted during the
    value analysis *)

(** Add a tab to the main GUI (for red alarms), and return its widget. *)
val make_panel: Design.main_window_extension_points -> GObj.widget
