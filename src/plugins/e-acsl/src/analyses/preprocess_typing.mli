(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

val type_program : file -> unit
(** compute and store the type of all the terms that will be translated
    in a program *)

val preprocess_predicate : Typing.Function_params_ty.t -> predicate -> unit
(** compute and store the types of all the terms in a given predicate  *)

val preprocess_rte : lenv:Typing.Function_params_ty.t -> code_annotation -> unit
(** compute and store the type of all the terms in a code annotation *)

val must_translate_ref : (Property.t -> bool) ref
val must_translate_opt_ref : (Property.t option -> bool) ref
