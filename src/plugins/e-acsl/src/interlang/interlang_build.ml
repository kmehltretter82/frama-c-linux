(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2025                                               *)
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
open Interlang


module Exp = struct
  let of_exp_node ?origin enode = {enode; origin}
  let of_lval ?origin lval = of_exp_node ?origin @@ Lval lval
  let of_integer ~origin n = of_exp_node ~origin @@ Integer n
  let of_sizeof ~origin ty = of_exp_node ~origin @@ SizeOf ty
end

module Lhost = struct
  let of_varinfo ?name vi =
    let name = Option.value ~default:vi.vname name in
    Interlang.(Var (Varinfo.logic {vi with vorig_name = name}))
end
