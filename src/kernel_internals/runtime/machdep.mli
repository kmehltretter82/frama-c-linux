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

(** Managing machine-dependent information. *)


(** Prints on the given formatter all [#define] directives
    required by [share/libc/features.h] and other system-dependent headers.
    @param censored_macros prevents the generation of directives for the
    builtin macros in [mach.custom_defs] whose names match. empty by default.
    @before 29.0-Copper censored_macros did not exist
*)
val gen_all_defines:
  Format.formatter ->
  ?censored_macros:Datatype.String.Set.t ->
  Cil_types.mach ->
  unit

(** generates a [__fc_machdep.h] file in a temp directory and returns the
    directory name, to be added to the search path for preprocessing stdlib.
    @param see {!gen_all_defines}
    @before 29.0-Copper censored_macros did not exist.
*)
val generate_machdep_header:
  ?censored_macros:Datatype.String.Set.t ->
  Cil_types.mach ->
  Filepath.Normalized.t
