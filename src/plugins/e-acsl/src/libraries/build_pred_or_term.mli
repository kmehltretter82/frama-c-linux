(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2025                                               *)
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

open Cil_types

(** A unified signature for building terms and expressions.
    Not to be confused with [Analyses_types.pred_or_term], which
    simply is the sum of both types, while here separate modules are provided
    for predicates and terms. *)
module type S = sig
  type t

  val mk_false : logic_type option -> t
  val mk_true : logic_type option -> t
  val mk_logic_body : t -> logic_body
  val mk_let : ?loc:location -> logic_info -> t -> t
  val mk_if : ?loc:location -> predicate -> t -> t -> t
  val mk_at : logic_label -> t -> t

  val visit : Visitor.frama_c_visitor -> t -> t
end

module Predicate : S with type t = predicate
module Term : S with type t = term
