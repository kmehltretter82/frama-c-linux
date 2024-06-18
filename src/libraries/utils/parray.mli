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

(* Persistent array, based on "A Persistent Union-Find Data Structure" by
   Sylvain Conchon and Jean-Chistophe Filliâtre. For further details, see
   https://www.lri.fr/~filliatr/ftp/publis/puf-wml07.pdf *)

type 'a t

val init : int -> (int -> 'a) -> 'a t
val get  : 'a t -> int -> 'a
val set  : 'a t -> int -> 'a -> 'a t
val fold : (int -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
val map  : ('a -> 'a) -> 'a t -> 'a t

val pretty :
  ?sep : Pretty_utils.sformat ->
  (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a t -> unit
