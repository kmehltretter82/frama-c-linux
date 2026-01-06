(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

open Memory

val add_path : map -> Spec.path -> node
val add_region : map -> Spec.region -> unit

type env = {
  map : map ;
  result : node option ;
  formals : domain Varinfo.Map.t ;
  property : Property.t ;
}

val add_addr_lval : env -> term_lval -> typ * node
val add_term_lval : env -> term_lval -> domain
val add_term      : env -> term      -> domain
val add_predicate : env -> predicate -> unit
val add_logic     : env -> logic_info -> domain
