(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

module Outputs = struct
  let ref_statement = ref (fun _ -> assert false)
  let ref_get_external = ref (fun _ -> assert false)
  let ref_get_internal = ref (fun _ -> assert false)

  let kinstr = function
    | Cil_types.Kstmt s -> Some (!ref_statement s)
    | Kglobal -> None

  let get_external kf = !ref_get_external kf
  let get_internal kf = !ref_get_internal kf
end

module Inputs = struct
  let ref_get_external = ref (fun _ -> assert false)

  let get_external kf = !ref_get_external kf
end

(** State_builder.of operational inputs
    - over-approximation of zones whose input values are read by each function,
      State_builder.of sure outputs
    - under-approximation of zones written by each function. *)
module Operational_inputs = struct
  module Record_Inout_Callbacks = Hook.Build (struct type t = Inout_type.t end)
end
