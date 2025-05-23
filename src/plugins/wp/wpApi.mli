(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
module InteractiveMode : Server.Data.S with type t = VCS.mode

val goals : Wpo.t Server.States.array
val getProvers : unit -> VCS.prover list
val setProvers : VCS.prover list -> unit

(* -------------------------------------------------------------------------- *)
