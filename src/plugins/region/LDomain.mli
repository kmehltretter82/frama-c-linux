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

open Format
open Cil_types
open Cil_datatype

type 'a t = private
  | Pure
  | Ptr    of 'a
  | Array  of 'a t
  | Record of 'a t Fieldinfo.Map.t
  | Logic  of logic_type_info * 'a t list

val is_pure : 'a t -> bool
val pretty : (formatter -> 'a -> unit) -> formatter -> 'a t -> unit

val pure : 'a t
val ptr : 'a -> 'a t
val scalar : 'a option -> 'a t
val array : 'a t -> 'a t
val field : fieldinfo -> 'a t -> 'a t
val logic : logic_type_info -> 'a t list -> 'a t

val merge : ('a -> 'a -> 'a) -> 'a t -> 'a t -> 'a t

(** Flattens and merge all pointed regions in the domain *)
val pointed : ('a -> 'a -> 'a) -> 'a t -> 'a option

val get_field : ('a -> 'a -> 'a) -> 'a t -> fieldinfo -> 'a t
val get_index : ('a -> 'a -> 'a) -> 'a t -> 'a t

val of_ltype : (unit -> 'a) -> (string -> 'a t) -> logic_type -> 'a t
val of_typ : (unit -> 'a) -> typ -> 'a t
