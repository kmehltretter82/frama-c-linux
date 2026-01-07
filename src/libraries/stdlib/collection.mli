(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** This modules provides functions to help writing collections datatypes.
    @since Frama-C+dev *)

(** Formatter for ["%a"] format *)
type 'a aformatter = Format.formatter -> 'a -> unit

(** Formatter for ["%t"] format *)
type tformatter = Format.formatter -> unit

(** Formats used with [fprintf] and alike. *)
type nonrec 'a format = ('a,Format.formatter,unit) format

(** Build a pretty printer for a collection using an iterator and a pretty
    printer of its items.
    @param format defines the format used to print the collection, e.g. "@[%t@]"
    @param item defines the format for an item of the collection, e.g. "@[%a@]"
    @param sep defines the format for the separator between items, e.g "@;,"
    @param iter is an iterator over the items of the collection. *)
val pretty_iter:
  format:(tformatter -> unit) format ->
  item:('a aformatter -> 'a -> unit) format ->
  sep:unit format ->
  iter:(('a -> unit) -> 'b -> unit) ->
  'a aformatter -> 'b aformatter

(** Build a pretty printer for a map collection using an iterator and a
    pretty printer of its bindings.
    @param format defines the format used to print the collection, e.g. "@[%t@]"
    @param item defines the format for a binding, e.g. "@[%a ->@ %a@]"
    @param sep defines the format for the separator between bindings, e.g "@;,"
    @param iter is an iterator over the elements of the collection. *)
val pretty_iter2:
  format:(tformatter -> unit) format ->
  item:('a aformatter -> 'a -> 'b aformatter -> 'b -> unit) format ->
  sep:unit format ->
  iter:(('a -> 'b -> unit) -> 'c -> unit) ->
  'a aformatter -> 'b aformatter -> 'c aformatter

(** [hash_iter iter hash x] hashes a collection [x] given an [iter] function on
    this collection and a [hash] function on its elements.
    @param limit is the maximum number of elements used for the hash; if
    collections bigger than this size are given, the remaining elements are
    ignored. Defaults to 16. *)
val hash_iter :
  ?limit:int ->
  (('a -> unit) -> 'b -> unit) -> ('a -> int) -> 'b -> int
