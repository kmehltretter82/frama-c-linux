(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** This modules provides utilities to use semantic tags to output color
    and style information on capable terminals.

    Standard tags can be used in format strings as in the following example.

    {[
      Format.printf "@{<bold>Bold Text} @{<red>Red Text}"
    ]}

    The name [s] of the string tags inside ["@{<s>}"] should match the
    corresponding style or color constructor. The comparison is
    case-insensitive. For colors, the color name may be prefixed by an optional
    "fg" for foreground color and by "bg" for background colors. Multiple tags
    can be given at once by separating them with a comma.

    {[
      Format.printf "@{<red,bold>Red & Bold Text}"
    ]}

    Alternatively, style tags may be output using the new [Style_tag] :

    {[
      Format.open_stag (Style_tag (Color Red))
    ]}

    For both versions, the semantic tags handlers have to be activated using
    the [enable] or [enable_on] functions below.

    See {!Format.stag} for details about semantic tags.
    @since Frama-C+dev *)

(** [is_supported ()] returns whether the current terminal supports ansi
    escape sequence, i.e. if it exports a [TERM] environnement
    variable that is not assigned "DUMB" *)
val is_supported : unit -> bool

(** Enable the style output on the given formatter. No support test is
    performed.
    @return a reset function that can be called to reset styles. *)
val enable_on : Format.formatter -> (unit -> unit)

(** Output colors. The associated string semantic tag is documented for each
    constructor. Note that there exists variants prefixed with "fg" and "bg"
    for each colors, for foreground and background. When no prefix is used,
    it means the foreground color. *)
type color =
  | Black   (** ["black"] *)
  | Red     (** ["red"]   *)
  | Green   (** ["green"] *)
  | Yellow  (** ["yellow"] *)
  | Blue    (** ["blue"] *)
  | Magenta (** ["magenta"] *)
  | Cyan    (** ["cyan"] *)
  | White   (** ["white"] *)
  | Orange  (** ["orange"] *)

(** Output Styles. The associated string semantic tag is documented for each
    constructor. *)
type style =
  | Bold                (** ["bold"] *)
  | Faint               (** ["faint"] *)
  | Italic              (** ["italic"] *)
  | Underline           (** ["underline"] *)
  | Blink               (** ["blink"] *)
  | Strike              (** ["strike"] *)
  | Foreground of color (** ["fgxxxx"] where ["xxxx"] is the color tag *)
  | Background of color (** ["bgxxxx"] where ["xxxx"] is the color tag *)

(** Extension of semantic tags for style information *)
type Format.stag += Style_tag of style

