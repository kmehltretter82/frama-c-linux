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

module type Table = sig
  val get_override: Cil_types.typ -> Cil_types.varinfo
  val get_globals: Cil_types.location -> Cil_types.global list
  val mark_as_computed: ?project:Project.t -> unit -> unit
end

module type Override_generator = sig
  val function_name: String.t
  val build_prototype: Cil_types.typ -> Cil_types.varinfo
  val finalize: Cil_types.varinfo -> Cil_types.location -> Cil_types.global
end

module Make_internal_table (M: Override_generator) =
  (State_builder.Hashtbl(Cil_datatype.Typ.Hashtbl) (Cil_datatype.Varinfo)
     (struct
       let size = 5
       let dependencies = [Ast.self]
       let name = "Override." ^ M.function_name
     end))

module Make (Generator: Override_generator) = struct
  module Internal_table = Make_internal_table(Generator)

  let get_override t = try
      Internal_table.find t
    with Not_found ->
      let fct = Generator.build_prototype t in
      Internal_table.add t fct ;
      fct

  let get_globals loc =
    let add_global _ vi l = (Generator.finalize vi loc) :: l in
    Internal_table.fold add_global []

  let mark_as_computed = Internal_table.mark_as_computed
end
