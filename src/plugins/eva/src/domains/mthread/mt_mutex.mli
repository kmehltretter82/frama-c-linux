(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Mt_utils

type value = Value.t

type status =
  | Locked (* Surely locked *)
  | Unlocked (* Maybe unlocked *)

module Register : sig
  include Datatype.S
  val id : t -> int
  val empty : t
  val top : t
  val is_included : t -> t -> bool
  val join : t -> t -> t
  val narrow : t -> t -> t

  val register : Mutex.t list -> t -> (t * value) Result.t
  val lock     : value -> t -> (t * value) Result.t
  val unlock   : value -> t -> (t * value) Result.t

  val locked_mutexes : t -> Mutex.Set.t
end
