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

open Cil_datatype

(** Points-to graphs datastructure. *)
module G: Graph.Sig.G

module LMap = Lval.Map

(** Type denothing an abstract state of the analysis. It is a graph containing
    all aliases and points-to information. *)
type t


(** pretty printer *)
val pretty : Format.formatter -> t -> unit

(** dot printer *)
val print_dot : string -> t -> unit

(** finds the vertex corresponding to a lval *)
val find_vertex : lval -> t -> G.V.t

(** finds the vertices pointed by a lval *)
val points_to : lval -> t -> G.V.t list

(** Functions for the analysis *)
val join : t -> G.V.t -> G.V.t -> t

val cjoin : t -> G.V.t -> G.V.t -> t

val set_type : t -> G.V.t -> G.V.t -> t

val assignment_x_y : t -> lval -> lval -> t

val assignment_x_addr_y : t -> lval -> lval -> t

val assignment_x_ptr_y : t -> lval -> lval -> t

val assignment_x_allocate_y : t -> lval -> lval -> t

val assignment_ptr_x_y : t -> lval -> lval -> t


(** Type denoting summaries of functions *)
type summary

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

(** Store the graph at each statement. *)
module Stmt_table: Table with type key = stmt and type value = G.t


(** Store the summary of each function. *)
module Function_table:
  Table with type key = kernel_function and type value = G.t

(** [do_stmt a s] computes the next state and stores it in [Stmt_table]. *)
val do_stmt: t -> stmt -> t

(** [make_summary a f] computes the summary of a function (and the
    next abstract state if needed) and stores the summary in
    [Function_table]. *)
val make_summary: t -> kernel_function -> t * summary
