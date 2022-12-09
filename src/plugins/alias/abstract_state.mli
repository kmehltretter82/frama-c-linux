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

open Cil_types

(** Points-to graphs datastructure. *)
module G: Graph.Sig.G

(** Type denothing an abstract state of the analysis. It is a graph containing
   all aliases and points-to information. *)
type t = G.t

(** Type denoting summaries of functions *)
type summary

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

(** Store the graph at each statement. *)
module Stmt_table: Table with type key = stmt and type value = t

(** Store the summary of each function. *)
module Function_table:
  Table with type key = kernel_function and type value = summary

(** [do_stmt a s] computes the next state and stores it in [Stmt_table]. *)
val do_stmt: t -> stmt -> t

(** [make_summary a f] computes the summary of a function (and the
    next abstract state if needed) and stores the summary in
    [Function_table]. *)
val make_summary: t -> kernel_function -> t * summary
