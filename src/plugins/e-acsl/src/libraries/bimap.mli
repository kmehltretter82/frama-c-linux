(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2025                                               *)
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

(** A bijective hash map implementation based on a pair of hash tables *)

module Make (H : Hashtbl.S) : sig
  val clear : unit -> unit

  val add : H.key -> H.key -> unit

  val tails : H.key -> H.key list
  val tail : H.key -> H.key
  val tail_opt : H.key -> H.key option

  val heads : H.key -> H.key list
  val head : H.key -> H.key
  val head_opt : H.key -> H.key option

  val tail_or_self : H.key -> H.key
  val head_or_self : H.key -> H.key
end
