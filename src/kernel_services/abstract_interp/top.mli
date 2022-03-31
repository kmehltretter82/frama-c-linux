(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

(** Types, monads and utilitary functions for lattices in which the top is
    managed separately from other values. *)

module Type : sig
  type 'a or_top = [ `Value of 'a | `Top ]

  (** This monad propagates the `Bottom value if needed. *)
  val (>>-) : 'a or_top -> ('a -> 'b or_top) -> 'b or_top

  (** Use this monad if the following function returns a simple value. *)
  val (>>-:) : 'a or_top -> ('a -> 'b) -> 'b or_top

  (** Binding operators, applicative syntax *)
  val (let+) : 'a or_top -> ('a -> 'b) -> 'b or_top
  val (and+) : 'a or_top -> 'b or_top -> ('a * 'b) or_top

  (** Binding operators, monad syntax *)
  val (let*) : 'a or_top -> ('a -> 'b or_top) -> 'b or_top
  val (and*) : 'a or_top -> 'b or_top -> ('a * 'b) or_top
end

type 'a or_top = 'a Type.or_top

(** Combination, if one is `Top, the combination is `Top *)
val zip : 'a or_top -> 'b or_top -> ('a * 'b) or_top

(** Conversion. *)
val to_option : 'a or_top -> 'a option
val of_option : 'a option -> 'a or_top

(** Pretty printing. *)
val pretty_top : Format.formatter -> unit (* for %t specifier *)
val pretty : (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a or_top -> unit
