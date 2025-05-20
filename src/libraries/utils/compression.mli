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

(** File compression. *)

include module type of Gzip

(** Implementation of {!Stdlib.input_value} for a {!Gzip.in_channel}. *)
val input_value : in_channel -> 'a

(** Implementation of {!Stdlib.unsafe_really_input} for a {!Gzip.in_channel}. *)
val unsafe_really_input : in_channel -> bytes -> int -> int -> unit

(** Implementation of {!Stdlib.output_value} for a {!Gzip.out_channel}. *)
val output_value : out_channel -> 'a -> unit
