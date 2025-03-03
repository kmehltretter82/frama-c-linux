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

type access_or_protection = Unaccessed | Mutexes of MtTypes.MutexPresence.t

type mutexes_by_access = {
  mutexes_for_read: access_or_protection;
  mutexes_for_write: access_or_protection;
}

module MutexesByAccess: sig
  type t = mutexes_by_access

  val pretty: t Pretty_utils.formatter
  val equal: t -> t -> bool
  val hash: t -> int

  val join: t -> t -> t

  val unaccessed: t
end

module LatticeMutexes: Lmap_bitwise.With_default with type t = mutexes_by_access

module MutexesByZone: Lmap_bitwise.Location_map_bitwise
  with type v = mutexes_by_access
