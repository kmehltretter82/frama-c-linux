(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

val valid_size: ?loc:Fileloc.t -> typ -> term -> identified_predicate

val is_allocable: ?loc:Fileloc.t -> term -> identified_predicate
val isnt_allocable: ?loc:Fileloc.t -> term -> identified_predicate

val assigns_result: ?loc:Fileloc.t -> typ -> term list -> from
val assigns_heap: term list -> from

val allocates_nothing: unit -> allocation
val allocates_result: ?loc:Fileloc.t -> typ -> allocation

val fresh_result: ?loc:Fileloc.t -> typ -> term -> identified_predicate
val null_result: ?loc:Fileloc.t -> typ -> identified_predicate
val aligned_result: ?loc:Fileloc.t -> typ -> identified_predicate
