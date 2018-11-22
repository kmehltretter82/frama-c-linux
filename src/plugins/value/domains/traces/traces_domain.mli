(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

(** Traces domain *)
open Cil_datatype

module Node : Datatype.S

module GraphShape : sig type 'value t end

type edge =
  | Assign of Node.t * Cil_types.lval * Cil_types.typ * Cil_types.exp
  | Assume of Node.t * Cil_types.exp * bool
  | EnterScope of Node.t * Cil_types.varinfo list
  | LeaveScope of Node.t * Cil_types.varinfo list
  (** For call of functions without definition *)
  | CallDeclared of Node.t * Cil_types.kernel_function * Cil_types.exp list * Cil_types.lval option
  | Loop of Node.t * Stmt.t * Node.t (** start *) * edge list GraphShape.t (** cfg of the loop **)
  | Msg of Node.t * string

module Edge : Datatype.S with type t = edge

module Graph : Hptmap_sig.S with type key = Node.t
                             and type v = edge list
                             and type 'a shape = 'a GraphShape.t

(** stack of open loops *)
type loops =
  | Base of Node.t * Graph.t (* current last *)
  | OpenLoop of Cil_types.stmt * Node.t (* start node *) * Graph.t (* last iteration *) * Node.t (** current *) * Graph.t * loops
  | UnrollLoop of Cil_types.stmt * loops

type state

val start: state -> Node.t
val current: state -> loops
val globals: state -> Cil_types.varinfo list
val entry_formals: state -> Cil_types.varinfo list

module D: Abstract_domain.Internal
  with type value = Cvalue.V.t
   and type location = Precise_locs.precise_location
   and type state = state
