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

(** Read and written memory zones at some given Analysis_location.t point.

    The data is projectified and depends on the analysis state. *)

(** Represents read and written memory zones. *)
type t = {
  read : Locations.Zone.t;
  written : Locations.Zone.t;
}

val add_read : Analysis_location.t -> Locations.Zone.t -> unit
(** [add_read aloc zone] adds the given [zone] as a "read" memory location to
    the given [aloc]. *)

val add_write : Analysis_location.t -> Locations.Zone.t -> unit
(** [add_write aloc zone] adds the given [zone] as a "written" memory location
    to the given [aloc]. *)

val mk_filter : filter_base:(Base.base -> bool) -> (t -> t)
(** [mk_filter ~filter_base] creates a filter function for the functions below
    from a function that filter bases. *)

val keep_globals_only : t -> t
(** [keep_globals_only access] filters the given memory locations to only keep
    those coming from global bases (cf. {!Base.is_global}). *)

val at : ?filter:(t -> t) -> Analysis_location.t -> t
(** [at ?filter aloc] returns the read and written zones for the given [aloc],
    filtered by [filter]. *)

val iter : ?filter:(t -> t) -> (Analysis_location.t -> t -> unit) -> unit
(** [iter ?filter f] iterates over all analysis location where a read or write
    access occurs and applies [f] on that access. The access is filtered by
    [filter] before being passed to [f]. *)

val fold : ?filter:(t -> t) ->
  (Analysis_location.t -> t -> 'acc -> 'acc) ->
  'acc ->
  'acc
(** [fold ?filter f acc] folds over all analysis location where a read or write
    access occurs and applies [f] on that access. The access is filtered by
    [filter] before being passed to [f]. *)

val pretty_debug : Format.formatter -> t -> unit
(** Pretty print read and written memory zones. *)

val dump : ?filter:(t -> t) -> Format.formatter -> unit
(** Dump the internal state regarding the read and written memory zones. The
    zones are being filtered by [filter] before being dumped. *)
