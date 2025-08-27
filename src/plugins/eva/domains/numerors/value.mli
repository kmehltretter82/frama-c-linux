(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

(** Numerors' abstract value, which computes a sound overapproximation of the
    floating-point expressions semantic. It is represented as a triplet
    containing a sound overapproximation of the real semantic along with sound
    overapproximations for the absolute and relative errors. Those
    overapproximations also performs a reduced product between the two errors.
    For more details, one can look at M. Jacquemin's thesis. *)

type ('context, 'value) builtin =
  'context -> 'value list -> 'value Eval.or_bottom

module Make (Model : IEEE754.Modeling) : sig
  include Abstract_value.Leaf with type context = Model.Context.t
  val track_variable : Cil_types.varinfo -> bool
  val of_scalars : Cil_types.fkind -> Model.scalar -> Model.scalar -> t
  val widen : Locations.Location_Bytes.widen_hint -> t -> t -> t
  val builtins : (string * (context, t) builtin) list
end
