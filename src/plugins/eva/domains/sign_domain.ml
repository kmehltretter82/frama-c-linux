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

open Cil_types

module Sign_Value = struct
  include Sign_value

  (* In this domain, we only track integer variables. *)
  let track_variable vi = Cil.isIntegralType vi.vtype

  (* The base lattice is finite, we can use join to perform widening *)
  let widen = join

  let builtins = []
end

module Name = struct let name = "sign" end
module Domain = Simple_memory.Make_Domain (Name) (Sign_Value)
include Domain

let registered =
  let name = "sign"
  and descr = "Infers the sign of program variables." in
  Abstractions.Domain.register ~name ~descr ~priority:4 (module Domain)
