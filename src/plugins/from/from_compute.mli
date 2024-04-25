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

(** Module implementing the computation of functional dependencies *)

open Cil_types

(** Computations of From can be done Functionwise (one result per function),
    or Callwise (one result by call). The signature [To_Use] is used to
    describe the functions that are different between the two implementations.*)
module type To_Use =
sig
  (** How to find the Froms for a given call during the analysis. *)
  val get_from_call : kernel_function -> stmt -> Eva.Assigns.t

  (** The Eva request that can be used to evaluate expressions at a given
      statement through the Eva public API. *)
  val stmt_request : stmt -> Eva.Results.request

  val keep_base : kernel_function -> Base.t -> bool
  (** Return true if the given base is in scope after a call to the given
      function. (In particular, formals and locals of the function must result
      in [false].) *)

  (** Clean the given from (that have been computed for the given function),
      optionally save them, and return the cleaned result. *)
  val cleanup_and_save : kernel_function -> Eva.Assigns.t -> Eva.Assigns.t
end

(** Function that compute the Froms from a given prototype, called
    in the given state *)
val compute_using_prototype_for_state :
  Cvalue.Model.t ->
  Kernel_function.t ->
  assigns ->
  Eva.Assigns.t


(** Functor computing the functional dependencies, according to the three
    modules above. *)
module Make (_: To_Use) : sig
  (** Compute the dependencies of the given function, and return them *)
  val compute_and_return : Kernel_function.t -> Eva.Assigns.t

  (** Compute the dependencies of the given function *)
  val compute : Kernel_function.t -> unit
end

(** Exception indicating that a given call statement was not evaluated. *)
exception Call_did_not_take_place
