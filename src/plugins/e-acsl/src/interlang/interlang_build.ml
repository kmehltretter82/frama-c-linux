(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
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
