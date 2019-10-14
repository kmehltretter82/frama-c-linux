(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

module type Generator = sig
  val function_name: String.t
  val build_function: Cil_types.typ -> Cil_types.fundec
  val build_spec: Cil_types.varinfo -> Cil_types.location -> Cil_types.funspec
end

module type Table = sig
  val get_varinfo: Cil_types.typ -> Cil_types.varinfo
  val get_globals: Cil_types.location -> Cil_types.global list
  val mark_as_computed: ?project:Project.t -> unit -> unit
end

module Make (M: Generator) : Table
