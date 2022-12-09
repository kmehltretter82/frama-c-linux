(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in 'Alias' (alias).             *)
(*                                                                        *)
(*  Copyright (C) 2022-2022                                               *)
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
(*  for more details (enclosed in the file LICENSE)                       *)
(*                                                                        *)
(**************************************************************************)



(** Module abstract_state *)

open Graph

open Cil_types

(** module for points-to graphs - persistant graph *)
module G : Sig.P

(** an abstract state is a graph containing all aliases and points-to
    information *)
type t = G.t

(** a type for summaries of functions *)
type summary

(** Hashtables to store the abstract states and summaries; *)
val stmt_table : t Cil_datatype.Stmt.Hashtbl.t

val function_table : summary Kernel_function.Hashtbl.t

(** [do_stmt a s] computes the next abstract state and stores it in
    stmt_table *)
val do_stmt : t -> stmt -> t

(** [make_summary a f] computes the summary of a function (and the
    next abstract state if needed) and stores the summary in
    function_table *)
val make_summary : t -> kernel_function -> t * summary
