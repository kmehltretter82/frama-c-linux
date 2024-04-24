(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

(* -------------------------------------------------------------------------- *)
(** Server API for WP *)
(* -------------------------------------------------------------------------- *)

val package : Server.Package.package

module Prover : Server.Data.S with type t = VCS.prover
module Provers : Server.Data.S with type t = VCS.prover list
module Result : Server.Data.S with type t = VCS.result
module Goal : Server.Data.S with type t = Wpo.t

val goals : Wpo.t Server.States.array
val getProvers : unit -> VCS.prover list
val setProvers : VCS.prover list -> unit

(* -------------------------------------------------------------------------- *)
