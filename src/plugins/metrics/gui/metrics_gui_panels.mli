(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** {1 GUI utilities for Metrics} *)

(** Initialize the main Metrics panel into an upper and lower part.
    @return a box containing the lower part of the panel where metrics can
    display their results.
*)
val init_panel : Design.main_window_extension_points -> GPack.box ;;

(** @return a value allowing to register the panel into the main GUI *)
val coerce_panel_to_ui : < coerce : 'a; .. > -> 'b -> string * 'a * 'c option  ;;

(** Display the list of list of strings in a LablGTK table object *)
val display_as_table : string list list -> GPack.box  -> unit ;;

(** Reset metrics panel to pristine conditions by removing children from
    bottom container
*)
val reset_panel : 'a -> unit ;;

(** register_metrics [metrics_name] [display_function] () adds a selectable
    choice for the metrics [metrics_name] and add a hook calling
    [display_function] whenever this metrics is selected and launched.
    If [apply] is true, [display_function] is immediately applied. [apply] is
    false by default.
*)
val register_metrics : ?apply:bool -> string -> (GPack.box -> unit) -> unit ;;
