(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type flags
type attr = [
  | `Nullable (** Might be null *)
  | `Allocated  (** Might be dynamically allocated *)
  | `Garbage  (** Might be non-initialized *)
  | `Validread (** Might have no write access  *)
]

val empty : flags
val add : attr -> flags -> flags
val mem : attr -> flags -> bool
val subset : flags -> flags -> bool
val union : flags -> flags -> flags (** Union of attributes *)

val bottom : flags
(** Neutral for merge *)

val merge : flags -> flags -> flags
(** Combine flags:
    - [`Nullable] if {i either} is nullable
    - [`Allocated] if {i either} is allocated
    - [`Garbage] if {i either} is garbage
    - [`Validread] if {i both} are validread
*)

val iter : (attr -> unit) -> flags -> unit

val pp_attr : Format.formatter -> attr -> unit
val pretty : Format.formatter -> flags -> unit

open Cil_types

val cvar : garbage:bool -> varinfo -> flags
val is_local : varinfo -> bool
val is_const : varinfo -> bool
val is_initialized : garbage:bool -> varinfo -> bool
