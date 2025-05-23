(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Numerors domain: computes over-approximations of the rounding errors bounds
    of floating-point computations.
    Nothing is exported: the domain is registered as an analysis abstraction
    in the Eva engine, enabled by the -eva-domains numerors option. *)

val registered : Abstractions.Domain.registered
