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

open Cil_types

module type Generator_sig = sig
  module Hashtbl: Datatype.Hashtbl
  type override_key = Hashtbl.key

  val function_name: string
  val well_typed_call: exp list -> bool
  val key_from_call: exp list -> override_key
  val retype_args: override_key -> exp list -> exp list
  val generate_prototype: override_key -> (string * typ)
  val generate_spec: override_key -> fundec -> location -> funspec
  val args_for_original: override_key -> fundec -> exp list
end

module type Builtin = sig
  module Enabled: Parameter_sig.Bool
  type override_key

  val function_name: string
  val well_typed_call: exp list -> bool
  val key_from_call: exp list -> override_key
  val retype_args: override_key -> exp list -> exp list
  val get_override: override_key -> fundec
  val get_kfs: unit -> kernel_function list
  val mark_as_computed:  ?project:Project.t -> unit -> unit
end

module Make_builtin (G: Generator_sig) : Builtin
