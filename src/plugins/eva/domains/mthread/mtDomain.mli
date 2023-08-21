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

open MtUtils
open Locations

type memory = { read : Zone.t ; written : Zone.t }
type return = { standard : Value.t }

module Domain : sig
  include Datatype.S_with_collections
  val threads : t -> MtThread.Register.t
  val mutexes : t -> MtMutex.Register.t
  val memory  : t -> memory
  val return  : t -> return
  val key : t Structure.Key_Domain.key
end

module Cache : sig
  type 'a t = 'a Cil_datatype.Stmt.Hashtbl.t
  val copy : unit -> Domain.t t
  val reset : unit -> unit
end

val domain : Abstractions.Domain.registered
