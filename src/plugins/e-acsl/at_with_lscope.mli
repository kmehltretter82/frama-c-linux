(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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
open Cil_datatype

(* Convert \at on terms or predicates in which we can find purely
  logic variable. *)

(**************************************************************************)
(*************************** Translation **********************************)
(**************************************************************************)

val to_exp:
  loc:Location.t -> kernel_function -> Env.t ->
  Misc.pred_or_term -> logic_label -> exp * Env.t

(*****************************************************************************)
(**************************** Handling memory ********************************)
(*****************************************************************************)

(* The different possible evaluations of the [\at] under study are
  stored in a memory location that needs to be alloted then freed.
  This part is designed for that purpose. *)

val get_mallocs: kernel_function -> stmt list
(* Get the list of [malloc] stmts that need to be inserted into [kf]. *)

val get_frees: kernel_function -> stmt list
(* Get the list of [malloc] stmts that need to be inserted into [kf]. *)

val remove_mallocs_and_frees: kernel_function -> unit
(* Remove all [malloc] and [free] stmts for [kf] from the internal table. *)

(**************************************************************************)
(********************** Forward references ********************************)
(**************************************************************************)

val predicate_to_exp_ref:
  (kernel_function -> Env.t -> predicate -> exp * Env.t) ref

val term_to_exp_ref:
  (kernel_function -> Env.t -> term -> exp * Env.t) ref