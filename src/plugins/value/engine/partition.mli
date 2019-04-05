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
      a ration stamp (represented by two integers) until there is no slevel
      left. The first number is attributed by the store it comes from, the
      second one is attributed by the last transfer.
      It is an option type, when there is no more ration stamp, this field is
      set to None; each new state will not be distinguished by this field.
    - Branches: This field enumerate the last junctions points passed through.
      The partitioning may chose how the branches are identified, but it
      is a First-In-First-Out set.
    - Loops: This field stores the loop iterations needed to reach this state
      for each loop we are currently in. It is stored in reverse order
      (innermost loop first) It also stores the maximum number of unrolling ;
      this number varies from a state to another, as it is computed from
      an expression evaluated when we enter the loop.
    - Static/Dynamic splits: track the splits applied to the state as a map
      from the expression of the split to the value of this expression. Since
      the split creates states in which the expression evalutates to a
      singleton, the values of the map are integers.
      Static splits are only evaluated when the annotation is encountered
      whereas dynamic splits are reevaluated regularly.

    A flow is a list of states accompanied by their key. It is used to
    transfer states from one partition to another. It doesn't enforce unicity
    of keys.
*)

type branch = int

module ExpMap = Cil_datatype.ExpStructEq.Map

type key

module Key : sig
  type t = key
  val zero : t
  val compare : t -> t -> int
  val pretty : Format.formatter -> t -> unit
  val exceed_rationing: t -> bool
end

type 'a partition

val empty : 'a partition
val is_empty : 'a partition -> bool
val size : 'a partition -> int
val to_list : 'a partition -> 'a list
val find : key -> 'a partition -> 'a
val replace : key -> 'a -> 'a partition -> 'a partition
val merge : (key -> 'a option -> 'b option -> 'c option) -> 'a partition ->
  'b partition -> 'c partition
val iter : (key -> 'a -> unit) -> 'a partition -> unit
val filter : (key -> 'a -> bool) -> 'a partition -> 'a partition
val map : ('a  -> 'a) -> 'a partition -> 'a partition
val map_filter : (key -> 'a -> 'b option) -> 'a partition -> 'b partition


(* Partitioning actions *)

type rationing
val new_rationing: limit:int -> merge:bool -> rationing

type unroll_limit =
  | ExpLimit of Cil_types.exp
  | IntLimit of int

type split_kind = Static | Dynamic

type action =
  | Enter_loop of unroll_limit
  | Leave_loop
  | Incr_loop
  | Branch of branch * int (* branch taken, max branches in history *)
  | Ration of rationing
  | Split of Cil_types.exp * split_kind * int
  | Merge of Cil_types.exp * split_kind
  | Update_dynamic_splits

exception InvalidAction


(* Flows *)

module MakeFlow (Abstract: Abstractions.Eva) :
sig
  type state = Abstract.Dom.t
  type t

  val empty : t

  val initial : state list -> t
  val to_list : t -> state list
  val of_partition : state partition -> t
  val to_partition : t -> state partition

  val is_empty : t -> bool
  val size : t -> int

  val union : t -> t -> t

  val transfer_keys : t -> action -> t
  val transfer_states : (state -> state list) -> t -> t
  val legacy_transfer_states : (state list -> state list) -> t -> t

  val iter : (state -> unit) -> t -> unit
end
