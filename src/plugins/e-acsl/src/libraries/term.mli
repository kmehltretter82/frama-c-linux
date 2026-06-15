(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

val strip_shallow_cast : term -> term
(** remove the first [TCast] if any. *)

val extract_integer : term -> Z.t option
(** return the integer value contained in a [TConst] node if any *)
