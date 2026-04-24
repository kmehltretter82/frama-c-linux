(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Memory locations.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)

open Cil_types

(** {2 Locations} *)

(** A {!Addresses.Bits.t} and a size in bits.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)
type location = private {
  addr : Addresses.Bits.t;
  size : Z_or_top.t;
}

(** @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)
module Location: Datatype.S with type t = location

val loc_top : location
val loc_bottom : location
val is_bottom_loc: location -> bool

val make_loc : Addresses.Bits.t -> Z_or_top.t -> location

val loc_equal : location -> location -> bool

(** [loc_addr_bytes l] returns the address set corresponding to the given
    location, i.e. the location without the size information.
    @before Frama-C+dev was named loc_to_loc_without_size *)
val loc_addr_bytes : location -> Addresses.Bytes.t

val loc_size : location -> Z_or_top.t

(** Kind of memory access. *)
type access = Read | Write | Object_pointer | Any_pointer

(** Conversion into a base access, with the size information.
    Accesses of unknown sizes are converted into empty accesses.  *)
val base_access: size:Z_or_top.t -> access -> Base.access

val is_valid : access -> location -> bool
(** Is the given location entirely valid, without any access or as a destination
    for a read or write access. *)

val valid_part : access -> ?bitfield:bool -> location -> location
(** Overapproximation of the valid part of the given location. Beware that
    [is_valid (valid_part loc)] does not necessarily hold, as garbled mix
    may not be reduced by [valid_part].
    [bitfield] indicates whether the location may be the one of a bitfield, and
    is true by default. If it is set to false, the location is assumed to be
    byte aligned, and its offset (expressed in bits) is reduced to be congruent
    to 0 modulo 8. *)

val invalid_part : location -> location
(** Overapproximation of the invalid part of a location *)
(* Currently, this is the identity function *)

val cardinal_zero_or_one : location -> bool
(** Is the location bottom or a singleton? *)

val valid_cardinal_zero_or_one : for_writing:bool -> location -> bool
(** Is the valid part of the location bottom or a singleton? *)

val filter_base: (Base.t -> bool) -> location -> location

val overlaps: partial:bool -> location -> location -> bool
(** Is there a possibly non-empty intersection between two given locations?
    If [partial] is true, returns true if the two locations may be overlapping
    without being equal. If [partial] is false, also returns true if the two
    locations may be equal. Returns false when the two locations cannot be
    overlapping. *)

val pretty : Format.formatter -> location -> unit
val pretty_english : prefix:bool -> Format.formatter -> location -> unit

(** {2 Conversion functions} *)

val enumerate_bits : location -> Memory_zone.t
val enumerate_bits_under : location -> Memory_zone.t

val enumerate_valid_bits : access -> location -> Memory_zone.t
(** @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)

val enumerate_valid_bits_under : access -> location -> Memory_zone.t

val zone_of_varinfo : varinfo -> Memory_zone.t
(** @since Carbon-20101201 *)

val loc_of_varinfo : varinfo -> location
val loc_of_base : Base.t -> location
val loc_of_typoffset : Base.t -> typ -> offset -> location

(** {2 Deprecated} *)

module Location_Bytes = Addresses.Bytes
[@@deprecated "Use Addresses.Bytes instead"]
[@@migrate { repl = Addresses.Bytes }]

module Location_Bits = Addresses.Bits
[@@deprecated "Use Addresses.Bits instead"]
[@@migrate { repl = Addresses.Bits }]

module Zone = Memory_zone
[@@deprecated "Use Memory_zone instead"]
[@@migrate { repl = Memory_zone }]

val loc_to_loc_without_size : location -> Addresses.Bytes.t
[@@deprecated "Use loc_addr instead"]
[@@migrate { repl = Rel.loc_addr }]

val loc_bytes_to_loc_bits : Addresses.Bytes.t -> Addresses.Bits.t
[@@deprecated "Use Addresses.Bits.of_bytes instead"]
[@@migrate { repl = Addresses.Bits.of_bytes }]

val loc_bits_to_loc_bytes : Addresses.Bits.t -> Addresses.Bytes.t
[@@deprecated "Use Addresses.Bits.to_bytes instead"]
[@@migrate { repl = Addresses.Bits.to_bytes }]

val loc_bits_to_loc_bytes_under : Addresses.Bits.t -> Addresses.Bytes.t
[@@deprecated "Use Addresses.Bits.to_bytes_under instead"]
[@@migrate { repl = Addresses.Bits.to_bytes_under }]
