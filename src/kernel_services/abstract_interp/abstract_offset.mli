(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

module type T =
sig
  type t

  val pretty : Format.formatter -> t -> unit
  val append : t -> t -> t (* Does not check that the appened offset fits *)
  val join : t -> t -> t
  val of_cil_offset : (Cil_types.exp -> Ival.t) -> Cil_types.typ -> Cil_types.offset -> t
  val of_ival : base_typ:Cil_types.typ -> typ:Cil_types.typ -> Ival.t -> t
  val of_term_offset : Cil_types.typ -> Cil_types.term_offset -> t
  val is_singleton : t -> bool
end

type typed_offset =
  | NoOffset of Cil_types.typ
  | Index of Ival.t * Cil_types.typ * typed_offset
  | Field of Cil_types.fieldinfo * typed_offset

module TypedOffset : T with type t = typed_offset
module TypedOffsetOrTop : T with type t = [ `Value of typed_offset | `Top ]
