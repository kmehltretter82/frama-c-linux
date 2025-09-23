(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** This modules provides utilities to use semantic tags to output color
    and style informations on capable terminals.

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

    See {!Format.stag} for details about semantic tags. *)

(** [is_supported ()] returns whether the current terminal supports ansi
    escape sequence, i.e. if it exports a [TERM] environnement
    variable that is not assigned "DUMB" *)
val is_supported : unit -> bool

(** Enable the style output on the given formatter. No support test is
    performed.
    @return a reset function that can be called to reset styles. *)
val enable_on : Format.formatter -> (unit -> unit)

(** Output colors *)
type color =
  | Black
  | Red
  | Green
  | Yellow
  | Blue
  | Magenta
  | Cyan
  | White
  | Orange

(** Output Styles *)
type style =
  | Bold
  | Faint
  | Italic
  | Underline
  | Blink
  | Strike
  | Foreground of color
  | Background of color

(** Extension of semantic tags for style information *)
type Format.stag += Style_tag of style

