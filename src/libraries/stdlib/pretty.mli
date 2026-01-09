(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** This modules provides pretty printing utilities. Same as {!Pretty_utils}
    but without dependencies to {!Fclib.List} or {!Fclib.Array}.
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

(** Pretty prints a sequence.
    @param format defines the format used to print the collection, e.g. "@[%t@]"
    @param item defines the format for an item of the collection, e.g. "@[%a@]"
    @param sep defines the format for the separator between items, e.g "@;,"
    @param last defines the format for the last separator, defaults to [sep]
    @param empty defines the format for empty sequences, defaults to [format] *)
val pretty_seq:
  format:(tformatter -> unit) format ->
  item:('a aformatter -> 'a -> unit) format ->
  sep:unit format ->
  ?last:unit format ->
  ?empty:unit format ->
  'a aformatter -> ('a Seq.t) aformatter
