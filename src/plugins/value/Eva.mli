(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

(** Analysis for values and pointers *)

module Value_results: sig
  type results

  val get_results: unit -> results
  val set_results: results -> unit
  val merge: results -> results -> results
  val change_callstacks:
    (Value_types.callstack -> Value_types.callstack) -> results -> results
end

module Value_parameters: sig
  (** Returns the list (name, descr) of currently enabled abstract domains. *)
  val enabled_domains: unit -> (string * string) list

  (** [use_builtin kf b] adds a builtin override for function [kf] to
      builtin {!b}. *)
  val use_builtin: Cil_types.kernel_function -> string -> unit
end

module Eval_terms: sig
  (** Evaluation environment, built by [env_annot]. *)
  type eval_env

  (** Dependencies needed to evaluate a term or a predicate. *)
  type logic_deps = Locations.Zone.t Cil_datatype.Logic_label.Map.t

  type labels_states = Db.Value.state Cil_datatype.Logic_label.Map.t

  val env_annot :
    ?c_labels:labels_states -> pre:Db.Value.state -> here:Db.Value.state ->
    unit -> eval_env

  (** [predicate_deps env p] computes the logic dependencies needed to evaluate
      [p] in the given evaluation environment [env].
      @return None on either an evaluation error or on unsupported construct. *)
  val predicate_deps: eval_env -> Cil_types.predicate -> logic_deps option
end
