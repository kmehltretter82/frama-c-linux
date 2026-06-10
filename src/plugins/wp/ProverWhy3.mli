(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

module CC :
sig
  type env
  val tvar : int -> Why3.Ty.tvsymbol
  val find_ts : env -> string -> Why3.Ty.tysymbol
  val find_ls : env -> string -> Why3.Term.lsymbol
  val cc_tau : env -> Lang.F.tau -> Why3.Ty.ty option
  val cc_term : env -> Lang.F.term -> Why3.Term.term
  val cc_pred : env -> Lang.F.pred -> Why3.Term.term
  val hack :
    Lang.lfun ->
    (env -> Lang.F.tau -> Lang.F.term list -> Why3.Term.term) -> unit
end

(** Return NoResult if it is already proved by Qed *)
val prove :
  ?mode:Prover.InteractiveMode.t ->
  ?timeout:float ->
  ?steplimit:int ->
  ?memlimit:int ->
  prover:Why3Env.prover -> Wpo.t -> VCS.result Task.task

(**************************************************************************)
