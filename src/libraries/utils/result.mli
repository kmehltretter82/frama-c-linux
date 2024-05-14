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

(* Adding let binding operators to the Result module. See
   https://v2.ocaml.org/manual/bindingops.html for more information. *)

include module type of Stdlib.Result

(** [zip r1 r2] regroups values in a pair [Ok (v1, v2)] if both arguments are
    [Ok v1] and [Ok v2] and propagate errors in other cases. If both [r1]
    and [r2] are errors we keep the first one, in this case [r1]. *)
val zip : ('a, 'e) result -> ('b, 'e) result -> ('a * 'b, 'e) result

module Operators : sig
  val ( let* ) : ('a, 'e) result -> ('a -> ('b, 'e) result) -> ('b, 'e) result
  val ( let+ ) : ('a, 'e) result -> ('a -> 'b) -> ('b, 'e) result
  val ( and* ) : ('a, 'e) result -> ('b, 'e) result -> ('a * 'b, 'e) result
  val ( and+ ) : ('a, 'e) result -> ('b, 'e) result -> ('a * 'b, 'e) result
end
