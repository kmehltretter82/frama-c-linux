(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Extension of OCaml's {!Stdlib.String} module.
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf>
    @since Frama-C+dev
*)

include module type of Stdlib.String

(** Case-insensitive string comparison. Only ISO-8859-1 accents are handled.
    @since Silicon-20161101 *)
val compare_ignore_case: string -> string -> int

(** [string_del_prefix ~strict p s] returns [None] if [p] is not a prefix of
    [s] and Some [s1] iff [s=p^s1].
    @since Oxygen-20120901 *)
val strip_prefix: ?strict:bool -> string -> string -> string option

(** [string_del_suffix ~strict suf s] returns [Some s1] when [s = s1 ^ suf]
    and None of [suf] is not a suffix of [s].
    @since Aluminium-20160501 *)
val strip_suffix: ?strict:bool -> string -> string -> string option

(** Same as {!String.escaped} but for utf8 encoded strings. Unicode non ASCII
    characters are preserved unescaped. *)
val utf8_escaped: string -> string

(** remove underscores at the beginning and end of a string. If a string
    is composed solely of underscores, return the empty string

    @since 18.0-Argon *)
val strip_underscores: string -> string

(** Escape string for use in HTML tag. *)
val html_escape: string -> string

(** [percent_encode s] returns the string [s] encoded so that it can be used
    as a path component in a HTML URL. All characters not on the list of
    unreserved characters in RFC3986 are percent-encoded. For instance the space
    character is converted to [%20].

    Cf. {{:https://datatracker.ietf.org/doc/html/rfc3986#section-2.3}} for the
    list of unreserved characters.

    @since 32.0-Germanium *)
val percent_encode: string -> string
