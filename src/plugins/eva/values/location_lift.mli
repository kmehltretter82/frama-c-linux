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
  val extend : internal -> extended
  val replace : internal -> extended -> extended
  val restrict : extended -> internal
end

module Make
    (Loc: Abstract_location.Leaf)
    (Convert : Conversion with type internal := Loc.value)
  : Abstract.Location.Internal with type location = Loc.location
                                and type offset = Loc.offset
                                and type value = Convert.extended


(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
