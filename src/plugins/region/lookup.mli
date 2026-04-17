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

type env = {
  map : map ;
  result : node option ; (* where returned value is stored *)
  formals : domain Varinfo.Map.t ;
  context : Access.clause ;
}

val lvar : env -> logic_var -> (varinfo, domain) Either.t

val lval : map -> lval -> node
val exp : map -> exp -> node option

val term : env -> term -> domain
val term_lval : env -> term_lval -> domain
