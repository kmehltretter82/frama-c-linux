(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

val tsizeof : ?smart:bool -> ?loc:Fileloc.t -> typ -> term
(** make a [sizeof(ty)] term. Optimisation depends on the [-e-acsl-O] option and
    [?smart]. *)

val talignof : ?smart:bool -> ?loc:Fileloc.t -> typ -> term
(** make a [alignof(ty)] term. Optimisation depends on the [-e-acsl-O] option
    and [?smart]. *)

val copy : ?smart:bool -> term -> term
(** copy a term using the [Terms.Id.deep_copy] function. Optimisation depends on
    the [-e-acsl-O] option and [?smart]. *)

val trange_array : ?smart:bool -> ?loc:Fileloc.t -> term -> term_lval
(** create the range for a given array and add it as an offset. For instance,
    using the function on [t] of type [int[3]] returns [t[0..2]]. In the case
    of a multi-dimensional array, it creates as many ranges as there are
    dimensions. Optimisation depends on the [-e-acsl-O] option. *)
