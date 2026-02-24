(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Side Condition Helpers                                             --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types

val addrof : ?loc:location -> lval -> term
val taddrof : ?loc:location -> term_lval -> term

val pvalid :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

val pvalid_read :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

val pvalid_region :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

val pinitialized :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

val paligned :
  ?loc:location -> ?names:string list ->
  term -> predicate

val is_valid_region : logic_info -> bool

type lkind = {
  host : varinfo option ;
  unsafe : bool ; (* cast or pointer arithmetics or unbounded array-index *)
}

val kind : exp -> lkind
val lkind : lval -> lkind
val hkind : lhost -> lkind
val safe_offset : typ -> offset -> bool
val term_kind : term -> lkind
val term_hkind : term_lhost -> lkind
val term_lkind : term_lval -> lkind
val safe_term_offset : logic_type -> term_offset -> bool
val default_kind : lkind

type residual =
  | Default
  | Residual of { validregion : bool ; condition : condition }
and condition = [ `True | `False | `Non_null ]

val rvalid : readonly:bool -> kinstr -> Memory.node -> lkind -> residual
val rinitialized : Memory.node -> lkind -> residual
val raligned : Memory.node -> lkind -> bits:int -> residual
