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


type lscope_var =
  | LvsLet of logic_var * term
  | LvsQuantif of term * logic_var * term
  | LvsFormal of logic_var * logic_info
  | LvsGlobal of logic_var * term

type lscope = lscope_var list (* TODO: maybe a Map is better *)

val add: lscope -> lscope_var -> lscope

val get_lscope_var: logic_var -> lscope -> lscope_var option

val add_malloc_and_free_stmt:  fundec -> stmt * stmt -> unit
val get_malloc_and_free_stmts: fundec -> stmt list * stmt list