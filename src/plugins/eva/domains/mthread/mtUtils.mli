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

val (<?>) : int -> int lazy_t -> int



module Result : sig
  type 'a t

  val ok : 'a -> 'a t
  val warning : 'a -> ('r, Format.formatter, unit, 'a t) format4 -> 'r
  val error : ('r, Format.formatter, unit, 'a t) format4 -> 'r

  val map : ('a -> 'b) -> ('a t -> 'b t)
  val bind : 'a t -> ('a -> 'b t) -> 'b t
  val join : 'a t t -> 'a t

  val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int
  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool
  val log : error : 'a -> 'a t -> 'a
  val value : 'a t -> 'a

  val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
  val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
end



type trilean = True | False | Unknown

module Trilean : sig
  include Datatype.S_with_collections with type t = trilean
  val top : t
  val is_included : t -> t -> bool
  val join : t -> t -> t
  val narrow : t -> t -> t
  val maybe_true  : t -> bool
  val maybe_false : t -> bool
  val of_bool : bool -> t
  val ( && ) : t -> t -> t
  val ( || ) : t -> t -> t
  val not : t -> t
end



module Value : sig
  include module type of (Cvalue.V)
  val zero : t
  val of_int : int -> t
  val to_int_list : t -> int list Result.t
  val extract_singleton : t -> int option
  val extract_fun : t -> Cil_types.kernel_function list Result.t
end
