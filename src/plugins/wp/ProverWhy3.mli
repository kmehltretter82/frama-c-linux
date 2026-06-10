(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Return NoResult if it is already proved by Qed *)
val prove :
  ?mode:Prover.InteractiveMode.t ->
  ?timeout:float ->
  ?steplimit:int ->
  ?memlimit:int ->
  prover:Why3Env.prover -> Wpo.t -> VCS.result Task.task

(**************************************************************************)
