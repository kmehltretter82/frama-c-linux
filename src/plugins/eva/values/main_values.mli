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

(** Main numeric values of Eva that can be used by abstract domains. *)

(** Main abstract values built over Cvalue.V, used by most domains. *)
module CVal: Abstract_value.Leaf
  with type t = Cvalue.V.t and type context = unit
val cval: CVal.t Abstract_value.dependencies

(** Dummy intervals: no forward nor backward propagations,
    only used as a reduced product with CVal above. [None] is top. *)
module Interval: Abstract_value.Leaf
  with type t = Ival.t option and type context = unit
val ival: Interval.t Abstract_value.dependencies

(** Simple sign values, used by the sign domain. *)
module Sign: Abstract_value.Leaf
  with type t = Sign_value.t and type context = unit
val sign: Sign.t Abstract_value.dependencies

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
