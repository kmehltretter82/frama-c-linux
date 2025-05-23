(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open VCS

(* -------------------------------------------------------------------------- *)
(* --- Prover Implementation against Task API                             --- *)
(* -------------------------------------------------------------------------- *)

val simplify :
  ?start:(Wpo.t -> unit) ->
  ?result:(Wpo.t -> prover -> result -> unit) ->
  ?commit:bool ->
  Wpo.t -> bool Task.task

val prove : Wpo.t ->
  ?config:config ->
  ?mode:mode ->
  ?start:(Wpo.t -> unit) ->
  ?progress:(Wpo.t -> string -> unit) ->
  ?result:(Wpo.t -> prover -> result -> unit) ->
  prover -> bool Task.task

val spawn : Wpo.t ->
  delayed:bool ->
  ?config:config ->
  ?start:(Wpo.t -> unit) ->
  ?progress:(Wpo.t -> string -> unit) ->
  ?result:(Wpo.t -> prover -> result -> unit) ->
  ?success:(Wpo.t -> prover option -> unit) ->
  ?pool:Task.pool ->
  (mode * prover) list -> unit
