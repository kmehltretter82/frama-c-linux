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

open Graph

module G = Persistent.Digraph.Concrete(Datatype.Int)

type t = G.t

(** a type for summaries of functions *)
type summary = t (* final type may be different *)

module type Table = sig
  type key
  type value
  val find: key -> value
  (** @raise Not_found if the key is not in the table. *)
end

module Make_table(H: Hashtbl.S)(V: sig type t end) = struct
  type key = H.key
  type value = V.t
  let tbl = H.create 7
  let find = H.find tbl
end

module Stmt_table = Make_table(Cil_datatype.Stmt.Hashtbl)(G)
module Function_table = Make_table(Kernel_function.Hashtbl)(G)

let do_stmt _ =
  failwith "not implemented"

let make_summary  _ =
  failwith "not implemented"
