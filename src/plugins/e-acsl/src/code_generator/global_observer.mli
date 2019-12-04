(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2018                                               *)
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

(** Observation of global variables. *)

open Cil_types

val function_name: string
(** name of the function in which [mk_init] generates the code *)

val reset: unit -> unit
val is_empty: unit -> bool

val add: varinfo -> unit
(** observes the given variable if necessary *)

val add_initializer: varinfo -> offset -> init -> unit
(** add the initializer for the given observed variable *)

val mk_init_function: unit -> varinfo * fundec
(** generates a new C function containing the observers for global variable
     declaration and initialization *)

val mk_delete_stmts: stmt list -> stmt list
(** generates the observers for global variable de-allocation *)

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
