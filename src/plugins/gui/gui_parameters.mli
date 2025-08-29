(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** GUI as a plug-in. *)

include Plugin.S

module Config_dir : Parameter_sig.User_dir

module Project_name: Parameter_sig.String
(** Option -gui-project. *)

module Undo: Parameter_sig.Bool
(** Option -undo. *)
