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

open Eval

module type Conversion = sig
  type extended
  type internal
  val extend : internal -> extended
  val replace : internal -> extended -> extended
  val restrict : extended -> internal
end

module Make
    (Loc: Abstract_location.Leaf)
    (Convert : Conversion with type internal := Loc.value)
= struct

  (* Import most of [Loc] *)
  include (Loc: Abstract_location.S
           with type value := Loc.value (* we are converting this type *)
            and type location = Loc.location
            and type offset = Loc.offset)
  type value = Convert.extended

  let structure = Abstract.Location.Leaf (Loc.key, (module Loc))

  (* Now lift the functions that contain {!value} in their type. *)

  let to_value loc = Loc.to_value loc >>-: Convert.extend

  let forward_index typ value offset =
    Loc.forward_index typ (Convert.restrict value) offset

  let forward_pointer typ value offset =
    Loc.forward_pointer typ (Convert.restrict value) offset

  let backward_pointer value offset loc =
    let v = Convert.restrict value in
    Loc.backward_pointer v offset loc >>-: fun (v, off) ->
    Convert.replace v value, off

  let backward_index typ ~index:value ~remaining offset =
    let index = Convert.restrict value in
    Loc.backward_index typ ~index ~remaining offset >>-: fun (v, off) ->
    Convert.replace v value, off
end


(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
