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

(** {2 Region Lookup for Code} *)

val lval : map -> lval -> node
val exp : map -> exp -> node option

(** {2 Region Lookup for Logic} *)

type env = {
  map : map ;
  result : node option ; (* where returned value is stored *)
  formals : domain Varinfo.Map.t ;
  context : Access.clause ;
}

val local : map -> Property.t -> env
val callsite : map -> stmt -> kernel_function -> env

val lvar : env -> logic_var -> (varinfo,domain) Either.t
(** Returns [Left v] when for C-variables and [Right d]
    for logic variable with domain [d] *)

val tval : env -> term_lval -> (node,domain) Either.t
(** Returns [Left n] for l-values located in node region [n].
    Returns [Right d] for logical value in domain [d]. *)

val tmem : env -> term -> node
(** Evaluate the term as a pointer and returns the node region it points to. *)

val term : env -> term -> domain
(** Evaluate the term as a logical value and returns its domain. *)
