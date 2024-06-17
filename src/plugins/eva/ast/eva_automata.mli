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

(** Eva automata are [Interpreted_automata] where transitions have been
    translated to the Eva AST and where useless transitions have been
    replaced by Skip. As such, it essentially differs by its simpler
    vertex, edge and transitions types. *)

open Cil_types
open Eva_ast

type vertex = private {
  vertex_key : int;
  vertex_start_of : Cil_types.stmt option;
  mutable vertex_wto_index : vertex list;
}

type guard_kind = Then | Else

type transition =
  | Skip
  | Enter of block
  | Leave of block
  | Return of exp option * stmt
  | Guard of exp * guard_kind * stmt
  | Assign of lval * exp * stmt
  | Call of lval option * exp * exp list * stmt
  | Init of varinfo * init * stmt
  | Asm of attributes * string list * extended_asm option * stmt

type edge = private {
  edge_key : int;
  edge_kinstr : kinstr;
  edge_transition : transition;
  edge_loc : location;
}

module G : Graph.Sig.I
  with type V.t = vertex
   and  type E.t = vertex * edge * vertex
   and  type V.label = vertex
   and  type E.label = edge

type graph = G.t

type wto = vertex Wto.partition

type automaton = {
  graph : graph;
  wto : wto;
  entry_point : vertex;
  return_point : vertex;
  stmt_table : (vertex * vertex) Cil_datatype.Stmt.Hashtbl.t;
}

module Transition : Datatype.S with type t = transition
module Vertex : Datatype.S_with_collections with type t = vertex
module Edge : Datatype.S_with_collections with type t = edge
module Automaton : Datatype.S with type t = automaton

val get_automaton : kernel_function -> automaton
val output_to_dot : out_channel -> automaton -> unit

(* Wto related functions *)

val exit_strategy : graph -> vertex Wto.component -> wto
val wto_index_diff : vertex -> vertex -> vertex list * vertex list
val is_wto_head : vertex -> bool
val is_back_edge : vertex * vertex -> bool
