(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Plugin Registration                                                --- *)
(* -------------------------------------------------------------------------- *)

include Plugin.S

(** Module activation *)
module Enabled : Parameter_sig.Bool

(** Displays the table [function -> summary] at the end of the analysis *)
module ShowFunctionTable : Parameter_sig.Bool

(** Displays the table [statement -> state] at the end of the analysis *)
module ShowStmtTable : Parameter_sig.Bool

(** Switch to debug mode when displaying tables *)
module DebugTable : Parameter_sig.Bool

(** Displays the final abstract state in Dot File <f> *)
module Dot_output : Parameter_sig.String

module Warn : sig
  val no_return_stmt : warn_category
  val undefined_function : warn_category
  val unsupported_address : warn_category
  val unsupported_asm : warn_category
  val unsupported_function : warn_category
  val unsafe_cast : warn_category
  val incoherent : warn_category
end

module DebugKeys : sig
  val lvals : category
end
