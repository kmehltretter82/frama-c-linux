(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

type 'a t
type 'a store

val forge : int -> 'a t
val key : 'a t -> int

(** Normalized id (if normalization is complete)*)
val id : 'a t -> int

val eq : 'a store -> 'a t -> 'a t -> bool

val get : 'a store -> 'a t -> 'a
val set : 'a store -> 'a t -> ?id:int -> 'a -> unit

val new_value : 'a store -> 'a -> 'a t
val normalize : 'a store -> 'a t -> 'a t
val union : 'a store -> 'a t -> 'a t -> 'a t

val list : 'a store -> 'a t list -> 'a t list

val new_store : unit -> 'a store
val copy : 'a store -> 'a store
