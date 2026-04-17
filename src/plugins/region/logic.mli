(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Memory
open Lookup

val add_addr_lval : loc:location -> env -> ?garbage:bool -> term_lval -> typ * node
val add_term_lval : loc:location -> env -> term_lval -> domain

val add_term : env -> term -> domain
val add_predicate : env -> predicate -> unit
val add_path : env -> Spec.region -> Spec.path -> node
val add_region : env -> Spec.region -> unit
