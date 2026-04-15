(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(* -------------------------------------------------------------------------- *)
(** {2 Logic Helpers} *)
(* -------------------------------------------------------------------------- *)

val addrof : ?loc:location -> lval -> term
val taddrof : ?loc:location -> term_lval -> term

val pnull :
  ?loc:location -> ?names:string list -> eq:bool ->
  term -> predicate

val pbounds :
  ?loc:location -> ?names:string list ->
  exp -> Z.t -> predicate

val pvalid :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

val pvalid_read :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

val pvalid_region :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

(** [p] is [\null] or [\object_pointer(p)], or [\valid_function(p)]
    for function pointers *)
val pvalid_pointer :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

val pinitialized :
  ?loc:location -> ?names:string list -> ?label:logic_label ->
  term -> predicate

val paligned :
  ?loc:location -> ?names:string list ->
  term -> typ -> predicate

val is_valid_region : logic_info -> bool
