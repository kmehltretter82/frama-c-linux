(**************************************************************************)
(*                                                                        *)
(*  This file is part of the E-ACSL plug-in of Frama-C.                   *)
(*                                                                        *)
(*  Copyright (C) 2011                                                    *)
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

val convert: 
  Env.t -> 
  location ->
  predicate named -> 
  logic_var list -> 
  predicate named -> 
  predicate named -> 
  exp * Env.t

val named_predicate_to_exp_ref: (Env.t -> predicate named -> exp * Env.t) ref
val term_to_exp_ref: (Env.t -> logic_type -> term -> exp * Env.t) ref

(*
Local Variables:
compile-command: "make"
End:
*)
