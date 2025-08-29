(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
