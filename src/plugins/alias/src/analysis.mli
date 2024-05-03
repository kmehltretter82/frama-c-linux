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

open Abstract_state

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

(** Store the graph at each statement. *)
module Stmt_table: Table with type key = stmt and type value = Abstract_state.t option


(** Store the summary of each function. *)
module Function_table:
  Table with type key = kernel_function and type value = Abstract_state.summary option

(** [do_stmt a s] computes the abstract state after statement s. This
    function does NOT store the result in Stmt_table.  *)
val do_stmt: t -> stmt -> t

(** [make_summary a f] computes the summary of a function (and the
    next abstract state if needed) and stores the summary in
    [Function_table]. *)
val make_summary: t -> kernel_function -> t * summary

(** main analysis functions *)

(** [compute ()] performs the may-alias analysis. It must be done once
    before using functions defined in API.ml *)
val compute : unit -> unit

(** [is_computed ()] returns true iff an analysis was done previously *)
val is_computed : unit -> bool

(** [clear()] clears caches and imperative structures that are used by
    the analysis. All accumulated data are lost. *)
val clear : unit -> unit

(** see API.mli *)
val get_state_before_stmt : stmt -> Abstract_state.t option

(** see API.mli *)
val get_summary : kernel_function -> Abstract_state.summary option
