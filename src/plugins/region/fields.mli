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

open Ranges
open Cil_types

type domain
type field = fieldinfo range
type slice = Bits of int | Field of fieldinfo

val empty : domain
val singleton : fieldinfo -> domain
val union : domain -> domain -> domain
val iter : (compinfo -> unit) -> domain -> unit
val compare : field -> field -> int
val find_all : domain -> 'a range -> field list
val find : domain -> 'a range -> field option
val span : domain -> 'a range -> slice list

val pp_bits : Format.formatter -> int -> unit
val pp_slice : Format.formatter -> slice -> unit

val pretty : domain -> Format.formatter -> 'a range -> unit
val pslice : Format.formatter -> fields:domain -> offset:int -> length:int -> unit
