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

open Nat.Types

module Make (Field : Field.S) : sig

  module Linear : module type of Linear.Space (Field)
  open Linear.Types
  open Field.Types

  module Types : sig type ('n, 'm) filter end
  open Types

  val create :
    ('n succ, 'n succ) matrix ->
    ('n succ, 'm succ) matrix ->
    'm succ vector -> ('n, 'm) filter

  val pretty : Format.formatter -> ('n, 'm) filter -> unit
  val invariant : ('n, 'm) filter -> scalar

end
