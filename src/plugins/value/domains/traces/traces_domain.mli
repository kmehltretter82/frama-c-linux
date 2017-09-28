(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2017                                               *)
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

module Node : Datatype.S

type edge =
  | Assign of Node.t * Cil_types.lval * Cil_types.typ * Cil_types.exp
  | Assume of Node.t * Cil_types.exp * bool
  | EnterScope of Node.t * Cil_types.varinfo list
  | LeaveScope of Node.t * Cil_types.varinfo list
  | Msg of Node.t * string
  | Top

module Edge : Datatype.S with type t = edge

module Graph : Hptmap_sig.S with type key = Node.t and type v = edge list

type state = { start : int; current : int; graph : Graph.t}

(* Lattice structure for the abstract state above *)
module Traces : sig
  include Datatype.S_with_collections with type t = state
  include Abstract_domain.Lattice with type state := state
end

module D: Abstract_domain.Internal
  with type value = Cvalue.V.t
   and type location = Precise_locs.precise_location
   and type state = state

val print_last_traces: unit -> unit
