(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(* [value_to_predicate_opt loc t value] may create a predicate given a [value]
   about some [term].
   @return None if no such predicate can be created. *)
val value_to_predicate_opt: ?loc:Fileloc.t -> term -> Cvalue.V.t ->
  predicate option

val lval_to_predicate: ?loc:Fileloc.t -> stmt -> lval -> predicate option
val exp_to_predicate: ?loc:Fileloc.t -> stmt -> exp -> predicate option
