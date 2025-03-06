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

type id_type

type raw_id = id_type * int
val pretty_raw_id : Format.formatter -> raw_id -> unit

val read_id_state : MtMemory.Types.state -> raw_id -> MtMemory.Types.value
val read_id_state_enumerate :
  int -> MtMemory.Types.state -> raw_id -> int list MtLib.conversion
val write_id_state :
  MtMemory.Types.state -> raw_id -> int -> MtMemory.Types.state
val replace_id_value :
  MtMemory.Types.state ->
  raw_id -> before:int -> after:int -> MtMemory.Types.state

val of_thread : Thread.t -> raw_id
val of_mutex: Mutex.t -> raw_id
val of_queue: Mqueue.t -> raw_id
