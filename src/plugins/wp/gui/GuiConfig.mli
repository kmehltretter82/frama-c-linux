(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* ------------------------------------------------------------------------ *)
(* ---  WP Provers Configuration Panel                                  --- *)
(* ------------------------------------------------------------------------ *)

class provers : [Why3.Whyconf.Sprover.t] Widget.selector

class dp_chooser :
  main:Design.main_window_extension_points ->
  provers:provers ->
  object
    method run : unit -> unit (** Edit enabled provers *)
  end

(* ------------------------------------------------------------------------ *)
