(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2015                                               *)
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
(*  for more details (enclosed in the file license/LGPLv2.1).             *)
(*                                                                        *)
(**************************************************************************)

(** Interval inference for terms.

    Compute the smallest interval that fits to contain all the possible values
    of a given integer term. *)

type interv = private { lower: Integer.t; upper: Integer.t }
include Datatype.S with type t = interv

(** Environment for interval computations. *)
module Env: sig
  val clear: unit -> unit
  val add: Cil_types.logic_var -> interv -> unit
(** Map an interval to a given logic variable *)
end

val interv_of_typ: Cil_types.typ -> t
(** @return the smallest interval which contains the given C type. *)

val add: t -> Integer.t -> t
(** Extend an interval in order to contain the given integer. *)

(** {3 Intervals as a lattice} *)

val join: t -> t -> t
val meet: t -> t -> t

(** {3 Inference system} *)

exception Not_an_integer
val infer: Cil_types.term -> t
(** [infer t] infers the smallest possible integer interval which the values
    of the term can fit in.
    @raise Not_an_integer if the type of the term is not a subtype of
    [Linteger]. *)

(*
Local Variables:
compile-command: "make"
End:
*)
