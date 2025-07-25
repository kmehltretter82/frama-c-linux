(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(** Text with Tags *)
(* -------------------------------------------------------------------------- *)

type message (** Message with tags *)

val size : message -> int
val char_at : message -> int -> char
val string : message -> string
val substring : message -> int -> int -> string

val tags_at : message -> int -> (Format.stag * int * int) list
(** Returns the list of tags at the given position.
    Inner tags come first, outer tags last. *)

(** [pretty fmt buffer] pretty-prints the message onto the given formatter
    [fmt], with the semantic tags.
    The original text has been {i already} laidout with respect to
    horizontal and vertical boxes, and this layout will be output as-it-is
    into the formatter.
    @param truncate do not print more than [truncate] characters; if the text
    size is bigger than this number, than the middle part of the text is
    replaced by [ellipsis]
    @param ellipsis when [truncate] is given and the text size is bigger than
    [truncate], then [ellipsis] is printed instead of the truncated middle
    part *)
val pretty :
  ?truncate:int ->
  ?ellipsis:string ->
  Format.formatter ->
  message ->
  unit


(* -------------------------------------------------------------------------- *)
(** Message Buffer  *)
(* -------------------------------------------------------------------------- *)

(** Buffer for creating messages.

    The buffer grows on demand, but is protected against huge messages.
    Maximal size is around 2 billions ASCII characters, which sould be enough
    to store more than 25kloc source text. *)
type buffer

(** Create a buffer.

    The right-margin is set to [~margin] and
    maximum indentation to [~indent].
    Default values are those of [Format.make_formatter], which are
    [~indent:68] and [~margin:78] in OCaml 4.05.
*)
val create : ?indent:int -> ?margin:int -> unit -> buffer

val message : ?trim:bool -> buffer -> message
(** Buffer contents, with its formatting tags.
    @param trim if sets to true, remove leading and trailing whitespases
    (including tabulations, line feed and carriage returns) *)

val add_char : buffer -> char -> unit (** Buffer-like *)

val add_string : buffer -> string -> unit (** Buffer-like *)

val add_substring : buffer -> string -> int -> int -> unit (** Buffer-like *)

val formatter : buffer -> Format.formatter

val bprintf : buffer -> ('a,Format.formatter,unit) format -> 'a
val kbprintf :
  (Format.formatter -> 'a) ->
  buffer -> ('b,Format.formatter,unit,'a) format4 -> 'b

(** Pretty prints to a string using a [Rich_text.buffer]. [prefix] can be used
    to setup semantic tag functions.
    @param prefix a pretty printing function called at the begining of the print
    @param suffix a pretty printing function called at the end of the print
    @param indent defines the maximum indentiation as in {!create}, defaults to
    20
    @param margin defines the right-margin as in {!create}, defaults to 40
    @param truncate do not print more than [truncate] characters; if the
    (trimed) buffer size is bigger than this number, than the middle part of the
    buffer is replaced by [ellipsis]
    @param ellipsis when [truncate] is given and the (trimed) buffer size is
    bigger than [truncate], then [ellipsis] is printed instead of the truncated
    middle part
    @param trim if sets to true, remove leading and trailing whitespas
    (including tabulations, line feed and carriage returns) *)
val sprintf  :
  ?prefix:(Format.formatter -> unit) -> ?suffix:(Format.formatter -> unit) ->
  ?indent:int -> ?margin:int ->
  ?trim:bool ->
  ?truncate:int -> ?ellipsis:string ->
  ('a, Format.formatter,unit,string) format4 -> 'a

(** Similar to {!Buffer.contents}, returns the plain contents of the buffer
    as a string.
    @param trim if sets to true, remove leading and trailing whitespases
    (including tabulations, line feed and carriage returns) *)
val contents : ?trim:bool -> buffer -> string

(** Similar to [Buffer.sub] *)
val sub : buffer -> int -> int -> string

(** Sub-string with range. [range b p q] is [sub b p (q+1-p)] *)
val range : buffer -> int -> int -> string

(** Range of non-blank leading and trailing characters. *)
val trim : buffer -> int * int

(** Reset the buffer to its initial empty state. *)
val reset : buffer -> unit

(** [truncate buffer size] truncates the content of [buffer] if longer than
    [size] characters. Returns true if the buffer has been truncated. *)
val truncate : buffer -> int -> bool

(* -------------------------------------------------------------------------- *)
