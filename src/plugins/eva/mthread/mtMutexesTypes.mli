(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

type access_or_protection = Unaccessed | Mutexes of MtTypes.presence

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
