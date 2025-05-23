(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

val update : unit -> unit
val on_update : (unit -> unit) -> unit

val reload : unit -> unit
val on_reload : (unit -> unit) -> unit

val run_and_prove :
  Design.main_window_extension_points ->
  GuiConfig.provers -> GuiSource.selection -> unit

val register :
  main:Design.main_window_extension_points ->
  configure_provers:(unit -> unit) -> unit
