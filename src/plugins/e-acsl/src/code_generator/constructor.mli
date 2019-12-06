(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2019                                               *)
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

(** Smart constructors for building C code. *)

open Cil_types
open Cil_datatype

val mk_deref: loc:Location.t -> exp -> exp
(** Make a dereference of an expression *)

val mk_block: stmt -> block -> stmt

(* ********************************************************************** *)
(* E-ACSL specific code *)
(* ********************************************************************** *)

val mk_lib_call: loc:Location.t -> ?result:lval -> string -> exp list -> stmt
(** Call of a library function.
    @raise Unregistered_library_function if the given string does not represent
    such a function or if these functions were never registered (only possible
    when using E-ACSL through its API). *)

val mk_rtl_call: loc:Location.t -> ?result:lval -> string -> exp list -> stmt
(** Special version of [mk_lib_call] for E-ACSL's RTL functions. *)

val mk_store_stmt: ?str_size:exp -> varinfo -> stmt
val mk_duplicate_store_stmt: ?str_size:exp -> varinfo -> stmt
val mk_delete_stmt: varinfo -> stmt
val mk_full_init_stmt: ?addr:bool -> varinfo -> stmt
val mk_initialize: loc:location -> lval -> stmt
val mk_mark_readonly: varinfo -> stmt

type annotation_kind =
  | Assertion
  | Precondition
  | Postcondition
  | Invariant
  | RTE

val mk_runtime_check:
  ?reverse:bool -> annotation_kind -> kernel_function -> exp -> predicate ->
  stmt
(** Generate a runtime check of the given expression. *)

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
