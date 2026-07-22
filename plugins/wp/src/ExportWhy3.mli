(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

val cc_task :
  ?probes:Lang.F.term Probe.Map.t ->
  ?axioms:Definitions.axioms ->
  pid:WpPropId.prop_id ->
  Lang.F.pred -> Why3.Task.task

(* -------------------------------------------------------------------------- *)
(* --- Compiler API                                                       --- *)
(* -------------------------------------------------------------------------- *)

module CC :
sig
  type env
  val export : string -> (env -> 'a) -> Why3.Theory.theory * 'a
  val cluster : env -> Qed.Symbol.cluster
  val find_ts : env -> string -> Why3.Ty.tysymbol
  val find_ls : env -> string -> Why3.Term.lsymbol
  val cc_tau : env -> Lang.F.tau -> Why3.Ty.ty option
  val cc_term : env -> Lang.F.term -> Why3.Term.term
  val cc_pred : env -> Lang.F.pred -> Why3.Term.term

  (**/**)
  val hack :
    Lang.lfun ->
    (env -> Lang.F.tau -> Lang.F.term list -> Why3.Term.term) -> unit

  (**/**)
end

(* -------------------------------------------------------------------------- *)
