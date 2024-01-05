(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

module Types : sig
  type 'a array
end

open Types

val init : int -> (int -> 'a) -> 'a array
val get  : 'a array -> int -> 'a
val set  : 'a array -> int -> 'a -> 'a array
val fold : (int -> 'a -> 'b -> 'b) -> 'a array -> 'b -> 'b
val map  : ('a -> 'a) -> 'a array -> 'a array

val pretty :
  ?pp_sep : (Format.formatter -> unit -> unit) ->
  (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a array -> unit
