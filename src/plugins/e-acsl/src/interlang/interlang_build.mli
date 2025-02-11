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

(** Smart constructors for building expressions of the intermediate language. *)

open Cil_types

module Exp : sig
  val of_exp_node :
    ?origin:term -> Interlang.exp_node -> Interlang.exp

  val of_lval :
    ?origin:term -> Interlang.lval -> Interlang.exp

  val of_integer : origin:term -> Z.t -> Interlang.exp
  val of_sizeof : origin:term -> typ -> Interlang.exp
end

module Lhost : sig
  val of_varinfo : ?name:string -> varinfo -> Interlang.lhost
end
