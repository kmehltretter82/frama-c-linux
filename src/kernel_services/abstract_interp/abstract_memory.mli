(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

type size = Integer.t

type bit =
  | Zero (* Zero everywhere *)
  | Any of Base.SetLattice.t (* Undetermined anywhere, and can contain bits
                                of pointers. If the base set is empty,
                                the bit can only come from numerical values. *)

module Bit :
sig
  type t = bit

  val top : t
  val numerical : t
  val zero : t
end

(* Values the memory is mapped to *)
module type Value =
sig
  type t

  val name : string

  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int

  val pretty : Format.formatter -> t -> unit
  val of_bit : bit -> t
  val to_bit : t -> bit
  val is_included : t -> t -> bool
  val join : t -> t -> t
end

module type Config =
sig
  val deps : State.t list
end

module type T =
sig
  type location
  type value
  type t

  (* Datatype *)
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int

  (* Infinite unknown memory *)
  val top : t

  (* Infinite zero memory *)
  val zero : t

  (* Is the memory map completely unknown ? *)
  val is_top : t -> bool

  (* Get a value from a set of locations *)
  val get : t -> location -> value

  (* Extract a sub map from a set of locations *)
  val extract : t -> location -> t

  (* Erase / initialize the memory on a set of locations. *)
  val erase : weak:bool -> t -> location -> bit -> t

  (* Set a value on a set of locations *)
  val set : weak:bool -> t -> location -> value -> t

  (* Copy a whole map over another *)
  val overwrite : weak:bool -> t -> location -> t -> t

  (* Reinforce values on a set of locations when the locations match the
     memory structure ; does nothing on locations that cannot be matched *)
  val reinforce : (value -> value) ->  t -> location -> t


  (* Test inclusion of one memory map into another *)
  val is_included : t -> t -> bool

  (* Finest partition that is coarcer than both *)
  val join : t -> t -> t

  (* Partition widening *)
  val widen : (size:size -> value -> value -> value) -> t -> t -> t

  val pretty : Format.formatter -> t -> unit
end

module Make (Config : Config) (Value : Value) : T
  with type value = Value.t
   and type location = Abstract_offset.typed_offset
