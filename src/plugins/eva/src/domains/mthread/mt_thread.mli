(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Mt_utils

type value = Value.t
type thread = Thread.t
type status = { running : Trilean.t ; canceled : Trilean.t }

val return_lval : Thread.t -> Eva_ast.lval option

module Register : sig
  include Datatype.S_with_collections
  val id : t -> int
  val empty : t
  val top : t
  val is_included : t -> t -> bool
  val join : t -> t -> t
  val narrow : t -> t -> t
  val find : thread -> t -> status option

  val register : thread list -> t -> (t * value) Result.t
  val start    : value -> t -> (t * value) Result.t
  val suspend  : value -> t -> (t * value) Result.t
  val cancel   : value -> t -> (t * value) Result.t
end
