(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

(*  A state partition is a collection of states, each of which is identified
    by a unique key. The key identifies the reason for which we want to keep
    the state separate from the others. The partitioning method will involve
    updating the key. If at some point two states share the same key, it means
    that the partitioning method decided to not consider those states separately
    anymore and that they should be joined together.

    The key have several fields, one for each kind of partitioning.

    - Ration stamps: These modelize the legacy slevel. Each state is given
      a ration stamp (represented by an integer) until there is no slevel left.
      It is an option type, when there is no more ration stamp, this field is
      set to None; each new state will not be distinguished by this field.
    - Branches: This field enumerate the last branches taken to reach this
      state. The partitioning may chose how the branches are identified, but it
      is a First-In-First-Out set.
    - Loops: This field stores the loop iterations needed to reach this state
      for each loop we are currently in. It is stored in reverse order
      (innermost loop first)
    - Static/Dynamic splits:

    Note on implementation. These partitions are implemented as map from keys
    to states. We chose to have the same partition for stores, propagation and
    widenings so the combination of propagation + store or propagation +
    widening can be done as a map2 operation. However, this involve some tricks
    to make keys be always distinguished in propagation, like giving them new
    ration stamps. It may have been more natural to consider that propagations
    are lists, allowing states to have the same key.
*)

type branch = int

module ExpMap = Cil_datatype.ExpStructEq.Map

type key = private {
  ration_stamp : int option;
  transfer_stamp : int option;
  branches : branch list;
  loops : int list;
  static_split : Integer.t ExpMap.t;
  dynamic_split : Integer.t ExpMap.t;
}

type 'a partition

type action =
  | Enter_loop
  | Leave_loop
  | Incr_loop of int (* the parameter is the unroll limit *)
  | Branch of branch * int (* branch taken, max branches in history *)
  | Ration of int (* starting ration stamp *)
  | Ration_merge of int option (* new ration stamp for the merge state *)
  | Transfer_merge
  | Static_split of Cil_types.exp
  | Dynamic_split of Cil_types.exp
  | Static_merge of Cil_types.exp
  | Dynamic_merge of Cil_types.exp
  | Update_dynamic_splits

exception InvalidAction


module type InputDomain =
sig
  type t

  exception Cant_split

  val join : t -> t -> t
  val split : t -> Cil_types.exp -> (Integer.t * t) list
end


module Make (Domain : InputDomain) :
sig
  type t = Domain.t partition
  type state = Domain.t

  val empty : 'a partition
  val is_empty : 'a partition -> bool
  val initial : 'a list -> 'a partition
  val size : 'a partition -> int
  val to_list : 'a partition -> 'a list

  val find : key -> 'a partition -> 'a
  val replace : key -> 'a -> 'a partition -> 'a partition
  val merge : ('a option -> 'b option -> 'c option) -> 'a partition
    -> 'b partition -> 'c partition
  val union : ('a -> 'a -> 'a) -> 'a partition -> 'a partition -> 'a partition

  val iter : ('a -> unit) -> 'a partition -> unit
  val transfer_keys : t -> action -> t
  val filter_keys : (key -> bool) -> 'a partition -> 'a partition
  val map_states : ('a  -> 'a) -> 'a partition -> 'a partition
  val transfer_states : ('a -> 'a list) -> 'a partition -> 'a partition
  val map_filter : (key -> 'a -> 'b option) -> 'a partition -> 'b partition
end
