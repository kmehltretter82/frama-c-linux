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

(** Generate C implementations of user-defined logic functions.
  A logic function can have multiple C implementations depending on
  the types computed for its arguments.
    Eg: Consider the following definition: [integer g(integer x) = x]
      with the following calls: [g(5)] and [g(10*INT_MAX)]
      They will respectively generate the C prototypes [int g_1(int)]
      and [long g_2(long)] *)

(**************************************************************************)
(************** Logic functions without labels ****************************)
(**************************************************************************)

val generate: loc:location -> Env.t -> term -> logic_info ->
  exp list -> logic_type list -> varinfo * exp * Env.t
(** [generate ~loc env t_app li args_exp args_lty] generates the C function
  corresponding to [t_app] and returns the associated call. *)

val do_visit: Cil_types.file -> unit
(** Put declarations and definitions of the generated functions in the AST. *)

(**************************************************************************)
(********************** Forward references ********************************)
(**************************************************************************)

val predicate_to_exp_ref:
  (kernel_function -> Env.t -> predicate -> exp * Env.t) ref

val term_to_exp_ref:
  (kernel_function -> Env.t -> term -> exp * Env.t) ref

val add_cast_ref:
  (location -> Env.t -> typ option -> bool -> exp -> exp * Env.t) ref