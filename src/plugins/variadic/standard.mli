(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

exception Translate_call_exn of Cil_types.varinfo

val fallback_fun_call :
  builder:Builder.t -> callee:Cil_types.varinfo ->
  Environment.t ->
  Va_types.variadic_function -> Cil_types.exp list -> unit

val aggregator_call :
  builder:Builder.t ->
  Va_types.aggregator ->
  Va_types.variadic_function -> Cil_types.exp list -> unit

val overloaded_call :
  builder:Builder.t ->
  Va_types.overload ->
  Va_types.variadic_function -> Cil_types.exp list -> unit

val format_fun_call :
  builder:Builder.t ->
  Environment.t ->
  Va_types.format_fun ->
  Va_types.variadic_function -> Cil_types.exp list -> unit
