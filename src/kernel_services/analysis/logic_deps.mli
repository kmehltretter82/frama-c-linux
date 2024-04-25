(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

val compute_term_deps: (stmt -> term -> Locations.Zone.t option) ref

type ctx

val mk_ctx_func_contract: ?before:bool -> kernel_function -> ctx
(** To build an interpretation context relative to function
    contracts. *)

val mk_ctx_stmt_contract: ?before:bool -> kernel_function -> stmt -> ctx
(** To build an interpretation context relative to statement
    contracts. *)

val mk_ctx_stmt_annot: kernel_function -> stmt -> ctx
(** To build an interpretation context relative to statement
    annotations. *)

type t = {before:bool ; ki:stmt ; zone:Locations.Zone.t}
type zone_info = (t list) option
(** list of zones at some program points.
    None means that the computation has failed. *)

type decl = {var: Cil_datatype.Varinfo.Set.t ; (* related to vars of the annot *)
             lbl: Cil_datatype.Logic_label.Set.t} (* related to labels of the annot *)
type pragmas =
  {ctrl: Cil_datatype.Stmt.Set.t ; (* related to //@ slice pragma ctrl/expr *)
   stmt: Cil_datatype.Stmt.Set.t}

val from_term: term -> ctx -> zone_info * decl
(** Entry point to get zones needed to evaluate the [term] relative to
    the [ctx] of interpretation. *)

val from_terms: term list -> ctx -> zone_info * decl
(** Entry point to get zones needed to evaluate the list of [terms]
    relative to the [ctx] of interpretation. *)

val from_pred: predicate -> ctx -> zone_info * decl
(** Entry point to get zones needed to evaluate the [predicate]
    relative to the [ctx] of interpretation. *)

val from_preds: predicate list -> ctx -> zone_info * decl
(** Entry point to get zones needed to evaluate the list of
    [predicates] relative to the [ctx] of interpretation. *)

val from_stmt_annot:
  code_annotation -> stmt * kernel_function ->
  (zone_info * decl) * pragmas
(** Entry point to get zones needed to evaluate an annotation on the
    given stmt. *)

val from_stmt_annots:
  (code_annotation -> bool) option ->
  stmt * kernel_function -> (zone_info * decl) * pragmas
(** Entry point to get zones needed to evaluate annotations of this
    [stmt]. *)

val from_func_annots:
  ((stmt -> unit) -> kernel_function -> unit) ->
  (code_annotation -> bool) option ->
  kernel_function -> (zone_info * decl) * pragmas
(** Entry point to get zones
    needed to evaluate annotations of this [kf]. *)

val code_annot_filter:
  code_annotation ->
  threat:bool -> user_assert:bool -> slicing_pragma:bool ->
  loop_inv:bool -> loop_var:bool -> others:bool -> bool
(** To quickly build an annotation filter *)

(** Does the interpretation of the predicate rely on the interpretation
    of the term result? *)
val to_result_from_pred: predicate -> bool

(** The following declarations are kept for compatibility and should not be
    used *)
exception NYI of string
val not_yet_implemented: string ref
