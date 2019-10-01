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
  val get_function: Cil_types.typ -> Cil_types.varinfo
  val get_globals: Cil_types.location -> Cil_types.global list
  val mark_as_computed: ?project:Project.t -> unit -> unit
end

module type Generator = sig
  val function_name: String.t
  val build_prototype: Cil_types.typ -> Cil_types.varinfo
  val build_spec: Cil_types.varinfo -> Cil_types.location -> Cil_types.funspec
end

module Make_internal_table (M: Generator) =
  (State_builder.Hashtbl(Cil_datatype.Typ.Hashtbl) (Cil_datatype.Varinfo)
     (struct
       let size = 5
       let dependencies = [Ast.self]
       let name = "Builtins." ^ M.function_name
     end))

module Make (Generator: Generator) = struct
  module Internal_table = Make_internal_table(Generator)

  let get_function t = try
      Internal_table.find t
    with Not_found ->
      let fct = Generator.build_prototype t in
      Internal_table.add t fct ;
      fct

  let get_globals loc =
    let finalize vi =
      let spec = Generator.build_spec vi loc in
      Globals.Functions.replace_by_declaration spec vi loc ;
      Cil_types.GFunDecl(Cil.empty_funspec(), vi, loc)
    in
    Internal_table.fold (fun _ vi l -> (finalize vi) :: l) []

  let mark_as_computed = Internal_table.mark_as_computed
end
