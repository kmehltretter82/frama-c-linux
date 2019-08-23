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

let ok = false

module type S = Abstract_domain.Leaf
  with type value = Main_values.Interval.t
   and type location = Precise_locs.precise_location

module U = struct
  include Unit_domain.Make (Main_values.Interval) (Main_locations.PLoc)
  let key = Structure.Key_Domain.create_key "dummy_apron"
end

module Octagon = U
module Box = U
module Polka_Loose = U
module Polka_Strict = U
module Polka_Equalities = U

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
