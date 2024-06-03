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

module type Conversion = sig
  type extended
  type internal
  val restrict : extended -> internal
end

module Make
    (Val: Abstract_value.Leaf)
    (Convert : Conversion with type internal := Val.context)
= struct

  (* Import most of [Val] *)
  include (Val: Abstract_value.S
           with type context := Val.context (* we are converting this type *)
            and type t = Val.t)
  type context = Convert.extended

  let structure = Abstract.Value.Leaf (Val.key, (module Val))

  let restrict context =
    let open Abstract_value in
    { from_domains = Convert.restrict context.from_domains }

  (* Now lift the functions that contain {!context} in their type. *)

  let constant context exp constant =
    Val.constant (restrict context) exp constant

  let forward_unop context typ unop value =
    Val.forward_unop (restrict context) typ unop value

  let forward_binop context typ binop left right =
    Val.forward_binop (restrict context) typ binop left right

  let rewrap_integer context range value =
    Val.rewrap_integer (restrict context) range value

  let forward_cast context ~src_type ~dst_type value =
    Val.forward_cast (restrict context) ~src_type ~dst_type value

  let backward_binop context ~input_type ~resulting_type binop ~left ~right ~result =
    Val.backward_binop (restrict context) ~input_type ~resulting_type binop ~left ~right ~result

  let backward_unop context ~typ_arg unop ~arg ~res =
    Val.backward_unop (restrict context) ~typ_arg unop ~arg ~res

  let backward_cast context ~src_typ ~dst_typ ~src_val ~dst_val =
    Val.backward_cast (restrict context) ~src_typ ~dst_typ ~src_val ~dst_val

end
