(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Memory

(** All the provided maps are locked. *)
type domain = map

(** The global map, if provided, is used as an accumulator. *)
val domain : ?global:map -> kernel_function -> domain
