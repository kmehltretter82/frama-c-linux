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

(* Adding let binding operators to the Option module. See
   https://v2.ocaml.org/manual/bindingops.html for more information. *)

include module type of Stdlib.Option

val zip : 'a option -> 'b option -> ('a * 'b) option

module Operators : sig
  val ( let* ) : 'a option -> ('a -> 'b option) -> 'b option
  val ( let+ ) : 'a option -> ('a -> 'b) -> 'b option
  val ( and* ) : 'a option -> 'b option -> ('a * 'b) option
  val ( and+ ) : 'a option -> 'b option -> ('a * 'b) option
end
