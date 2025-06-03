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

(** Functions manipulating normalized filepaths.
    In these functions, references to the current working directory refer
    to the result given by function Sys.getcwd.
*)

(** A normalized (absolute) path. *)
type t = private string


(* ************************************************************************* *)
(** {2 Basic datatype functions} *)
(* ************************************************************************* *)

(** [Filepath.t] is a Frama-C datatype, and comes with usual [compare], [equal],
    [hash] and [pretty] functions.

    Pretty-print is done according to these rules:
    - relative filenames are kept, except for leading './', which is stripped;
    - absolute filenames are relativized if their prefix is included in the
      current working directory; also, symbolic names are resolved,
      i.e. the result may be prefixed by known aliases (e.g. FRAMAC_SHARE).
      See {!add_symbolic_dir} for more details.
      Therefore, the result of this function may not designate a valid name
      in the filesystem and must ONLY be used to pretty-print information;
      it must NEVER be converted back to a filepath later on. *)

include Datatype.S_with_collections with type t := t

(** Compares prettified (i.e. relative) paths, with or without
    case sensitivity (by default, [case_sensitive = false]). *)
val compare_pretty : ?case_sensitive:bool -> t -> t -> int

(** Pretty-prints as absolute path, without symbolic names. *)
val pretty_abs: Format.formatter -> t -> unit

(** Pretty-prints as relative path relative to current working directory,
    without symbolic names. *)
val pretty_rel: Format.formatter -> t -> unit


(* ************************************************************************* *)
(** {2 Constant paths} *)
(* ************************************************************************* *)

(** Empty filepath.
    @since 23.0-Vanadium.
*)
val empty: t

(** @since 23.0-Vanadium *)
val is_empty: t -> bool

(** [is_special_stdout f] returns [true] iff [f] is '-' (a single dash),
    which is a special notation for 'stdout'.
    @since 23.0-Vanadium *)
val is_special_stdout: t -> bool


(* ************************************************************************* *)
(** {2 Path manipulation} *)
(* ************************************************************************* *)

(** Existence requirement on a file. *)
type existence =
  | Must_exist      (** File must exist. *)
  | Must_not_exist  (** File must not exist. *)
  | Indifferent     (** No requirement. *)

exception No_file
(** Raised whenever no file exists and [existence] is [Must_exist]. *)

exception File_exists
(** Raised whenever some file exists and [existence] is [Must_not_exist]. *)

(** Returns an absolute path leading to the given file.
    The result is similar to [realpath --no-symlinks].
    Some special behaviors include:
    - [normalize ""] (empty string) returns ""
      (realpath returns an error);
    - [normalize] preserves multiple sequential '/' characters,
      unlike [realpath];
    - non-existing directories in [realpath] may lead to ENOTDIR errors,
      but [normalize] may accept them.

    @before 21.0-Scandium no [existence] argument.
    @before 31.0-Gallium this function was [normalize] *)
val of_string: ?existence:existence -> ?base:t -> string -> t

(** [to_string p] returns [p] prettified, that is, a relative path-like string.
    The resulting string may contain symbolic dirs, thus it is not a path. *)
val to_string: t -> string

(** [to_string_rel ?quoted ?base p] returns [p] relativized, if relative to
    [base], or its absolute path otherwise. The resulting string has no symbolic
    names, thus it can be converted back to [Filepath.t].
    @param ?quoted if set the string will be suitable for use as one argument
           in a command line, defaults to false.
    @param ?base the base directory to be relative to, defaults to current
           working directory.
    @since Aluminium-20160501
    @before 31.0-Gallium was named relativize, argument types were string instead
    of t and the named argument was [base_name] *)
val to_string_rel: ?quoted:bool -> ?base:t -> t -> string

(** [to_string_abs p] returns [p] absolutized. The resulting string has no
    symbolic names, thus it can be converted back to [Filepath.t].
    @param ?quoted if set the string will be suitable for use as one argument
           in a command line, defaults to false
    @since 31.0-Gallium *)
val to_string_abs: ?quoted:bool -> t -> string

(** [to_string_list l] returns [l] as a list of strings containing the
    absolute paths to the elements of [l].
    @since 23.0-Vanadium *)
val to_string_list: t list -> string list

(** [to_base_uri path] returns a pair [base, rest], according to the
    prettified value of [path]:
    - if it starts with symbolic path SYMB, prefix is Hpath.Name "SYMB";
    - if it is a relative path, prefix is Hpath.Cwd;
    - else (an absolute path), prefix is Hpath.Absolute.
      [rest] contains everything after the '/' following the prefix.
      E.g. for the path "FRAMAC_SHARE/libc/string.h", returns
      (Name "FRAMAC_SHARE", "libc/string.h").

    @since 22.0-Titanium *)
val to_base_uri: t -> Hpath.base * string

(** Equivalent to [Filename.basename].
    @since 28.0-Nickel *)
val basename: t -> string

(** Equivalent to [Filename.dirname].
    @since 28.0-Nickel *)
val dirname: t -> t

(** [extend ~existence file ext] returns the normalized path to the file
    [file] ^ [ext]. Note that it does not introduce a dot.
    The resulting path must respect [existence].

    @since 29.0-Copper
    @before 31.0-Gallium this function was [Normalize.extend] *)
val extend: ?existence:existence -> t -> string -> t

(** [concat ~existence dir file] returns the normalized path
    resulting from the concatenation of [dir] ^ "/" ^ [file].
    The resulting path must respect [existence].

    @since 22.0-Titanium *)
val concat: ?existence:existence -> t -> string -> t

(** Operator version of {!Filepath.concat}. [Filepath.(file / ext)] is
    equivalent to [Filepath.concat file ext]. *)
val (/): t -> string -> t

(** [concats ~existence dir paths] concatenates a list of paths, as per
    the [concat] function.

    @since 28.0-Nickel *)
val concats: ?existence:existence -> t -> string list -> t

(** Same as [Filename.check_suffix].
    @since 31.0-Gallium *)
val has_suffix: t -> string -> bool

(** Same as [Filename.chop_suffix].
    @raise Invalid_argument if the suffix does not appear in the filepath.
    @since 31.0-Gallium *)
val chop_suffix: t -> string -> t

(** @return true if the file is relative to [base]
    (that is, it is prefixed by [base]), or to the current
    working directory if no base is specified.
    @since Aluminium-20160501
    @before 23.0-Vanadium argument types were string instead of t.
    @before 31.0-Gallium named argument was [base_name] *)
val is_relative: ?base:t -> t -> bool


(* ************************************************************************* *)
(** {2 Current working directory} *)
(* ************************************************************************* *)

(** @return the current working directory.
    Implicitly uses {!Unix.realpath} to normalize paths and avoid issues with
    symbolic links in directory names.

    @since 25.0-Manganese
    @before 28.0-Nickel return type was string instead of t. *)
val pwd : unit -> t


(* ************************************************************************* *)
(** {2 Symboling Names} *)
(* ************************************************************************* *)

(** [add_symbolic_dir name dir] indicates that the (absolute) path [dir] must
    be replaced by [name] when pretty-printing paths.
    This alias ensures that system-dependent paths such as FRAMAC_SHARE are
    printed identically in different machines. *)
val add_symbolic_dir: string -> t -> unit

val add_symbolic_dir_list: string -> t list -> unit

(** Remove all symbolic dirs that have been added earlier.
    @since 31.0-Gallium *)
val remove_symbolic_dir: t -> unit

(** Remove all symbolic dirs that have been added earlier.
    @since 23.0-Vanadium *)
val reset_symbolic_dirs: unit -> unit

(** Returns the list of symbolic dirs added via [add_symbolic_dir], plus
    preexisting ones (e.g. FRAMAC_SHARE), as pairs (name, dir).
    @since 22.0-Titanium *)
val all_symbolic_dirs: unit -> (string * t) list


(* ************************************************************************* *)
(** {2 Position in source file} *)
(* ************************************************************************* *)

(** Describes a position in a source file.
    @since 18.0-Argon *)
type position =
  {
    pos_path : t;
    pos_lnum : int;
    pos_bol : int;
    pos_cnum : int;
  }

(** Empty position, used as 'dummy' for [Cil_datatype.Position].
    @since 30.0-Zinc *)
val empty_pos : position

(** Pretty-prints a position, in the format file:line.
    @since 18.0-Argon *)
val pp_pos : Format.formatter -> position -> unit

(** Return true if the given position is the empty position.
    @since 30.0-Zinc *)
val is_empty_pos : position -> bool


(* ************************************************************************* *)
(** {2 Deprecated functions} *)
(* ************************************************************************* *)

val normalize: ?existence:existence -> ?base_name:string -> string -> string
[@@deprecated "Use Filepath.of_string instead."]

val relativize: ?base:t -> t -> string
[@@deprecated "Use Filepath.to_string_rel instead."]

val exists: t -> bool
[@@deprecated "Use Filesystem.exists instead"]
[@@migrate { repl = Filesystem.exists } ]

val is_file: t -> bool
[@@deprecated "Use Filesystem.is_file instead"]
[@@migrate { repl = Filesystem.is_file } ]

val is_dir: t -> bool
[@@deprecated "Use Filesystem.is_dir instead"]
[@@migrate { repl = Filesystem.is_dir } ]

val readdir: t -> string array
[@@deprecated "Use Filesystem.readdir instead"]
[@@migrate { repl = Filesystem.readdir } ]

val remove: t -> unit
[@@deprecated "Use Filesystem.remove_file instead"]
[@@migrate { repl = Filesystem.remove_file } ]

val rename: t -> t -> unit
[@@deprecated "Use Filesystem.rename instead"]
[@@migrate { repl = Filesystem.rename } ]

val copy_file : t -> t -> unit
[@@deprecated "Use Filesystem.copy_file instead"]
[@@migrate { repl = Filesystem.copy_file } ]

val iter_lines : t -> (string -> unit) -> unit
[@@deprecated "Use Filesystem.iter_lines instead"]
[@@migrate { repl = Filesystem.iter_lines } ]

module Normalized: sig
  type nonrec t = t
  val of_string: ?existence:existence -> ?base_name:string -> string -> t
  val extend: ?existence:existence -> t -> string -> t
  val concat: ?existence:existence -> t -> string -> t
  val concats: ?existence:existence -> t -> string list -> t
  val to_pretty_string: t -> string
  val to_string_list: t list -> string list
  val equal: t -> t -> bool
  val compare: t -> t -> int
  val compare_pretty : ?case_sensitive:bool -> t -> t -> int
  val pretty: Format.formatter -> t -> unit
  val pp_abs: Format.formatter -> t -> unit
  val empty: t
  val is_empty: t -> bool
  val is_special_stdout: t -> bool
  val is_file: t -> bool
  [@@deprecated "Use Filesystem.is_file."]
  val to_base_uri: t -> string option * string
end
[@@deprecated "Use Filepath directly instead."]
