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

val gcd : int -> int -> int
val (%.) : int -> int -> int (** gcd *)

type 'a range = { offset : int; length : int; data : 'a; }
type 'a t = private R of 'a range list (* sorted, no overlap *)

(** Prints [offset..last] formatted with [%04d] *)
val pp_range : Format.formatter -> 'a range -> unit

(** Prints [offset:length] formatted with [%04d] *)
val pp_offset : Format.formatter -> 'a range -> unit

val empty : 'a t
val singleton : 'a range -> 'a t
val range : ?offset:int -> ?length:int -> 'a -> 'a t
val merge : ('a range -> 'a range -> 'a) -> 'a t -> 'a t -> 'a t
val squash : ('a -> 'a -> 'a) -> 'a t -> 'a option

val find : int -> 'a t -> 'a range
val map : ('a -> 'b) -> 'a t -> 'b t
val iter : ('a -> unit) -> 'a t -> unit
val iteri : ('a range -> unit) -> 'a t -> unit
