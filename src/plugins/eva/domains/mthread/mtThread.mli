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

open MtUtils
open Cil_types

type name = Name.t
type value = Value.t
type thread
include Datatype.S_with_collections with type t = thread

val dummy : thread
val main : unit -> thread
val create : name -> stmt -> kernel_function -> (varinfo * value) list -> thread

val id : thread -> value
val of_cvalue : value -> thread Result.t
val to_cvalue : thread -> value
val return_lval : thread -> Eva_ast.lval option

module Register : sig
  include Datatype.S_with_collections
  val id : t -> int
  val empty : t
  val top : t
  val is_included : t -> t -> bool
  val join : t -> t -> t
  val narrow : t -> t -> t

  val register : thread -> t -> (t * value) Result.t
  val start    : thread -> t -> (t * value) Result.t
  val suspend  : thread -> t -> (t * value) Result.t
  val cancel   : thread -> t -> (t * value) Result.t
end
