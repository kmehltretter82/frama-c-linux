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

(** Functions manipulating filepaths.
    In these functions, references to the current working directory refer
    to the result given by function Sys.getcwd.

    NOTE: Prefer using the [Normalized] module whenever possible.
*)

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
*)
val normalize: ?existence:existence -> ?base_name:string -> string -> string

(** [relativize base_name file_name] returns a relative path name of
    [file_name] w.r.t. [base_name], if [base_name] is a prefix of [file];
    otherwise, returns [file_name] unchanged.
    The default base name is the current working directory name.
    @since Aluminium-20160501 *)
val relativize: ?base_name:string -> string -> string

(** The [Normalized] module is simply a wrapper that ensures that paths are
    always normalized. Used by [Datatype.Filepath].
    @since 18.0-Argon *)
module Normalized: sig

  (** The normalized (absolute) path. *)
  type t = private string

  (** [of_string s] converts [s] into a normalized path.
      @raise Invalid_argument if [s] is the empty string.
      @before 21.0-Scandium no [existence] argument.
  *)
  val of_string: ?existence:existence -> ?base_name:string -> string -> t

  (** [extend ~existence file ext] returns the normalized path to the file
      [file] ^ [ext]. Note that it does not introduce a dot.
      The resulting path must respect [existence].

      @since 29.0-Copper
  *)
  val extend: ?existence:existence -> t -> string -> t

  (** [concat ~existence dir file] returns the normalized path
      resulting from the concatenation of [dir] ^ "/" ^ [file].
      The resulting path must respect [existence].

      @since 22.0-Titanium
  *)
  val concat: ?existence:existence -> t -> string -> t

  (** [concats ~existence dir paths] concatenates a list of paths, as per
      the [concat] function.

      @since 28.0-Nickel
  *)
  val concats: ?existence:existence -> t -> string list -> t

  (** [to_pretty_string p] returns [p] prettified,
      that is, a relative path-like string.
      Note that this prettified string may contain symbolic dirs and is thus
      is not a path.
      See [pretty] for details about usage. *)
  val to_pretty_string: t -> string

  (** [to_string_list l] returns [l] as a list of strings containing the
      absolute paths to the elements of [l].
      @since 23.0-Vanadium
  *)
  val to_string_list: t list -> string list

  val equal: t -> t -> bool

  (** Compares normalized paths *)
  val compare: t -> t -> int

  (** Compares prettified (i.e. relative) paths, with or without
      case sensitivity (by default, [case_sensitive = false]). *)
  val compare_pretty : ?case_sensitive:bool -> t -> t -> int

  (** Pretty-print a path according to these rules:
      - relative filenames are kept, except for leading './',
        which are stripped;
      - absolute filenames are relativized if their prefix is included in the
        current working directory; also, symbolic names are resolved,
        i.e. the result may be prefixed by known aliases (e.g. FRAMAC_SHARE).
        See {!add_symbolic_dir} for more details.
        Therefore, the result of this function may not designate a valid name
        in the filesystem and must ONLY be used to pretty-print information;
        it must NEVER to be converted back to a filepath later.
  *)
  val pretty: Format.formatter -> t -> unit

  (** Pretty-prints the normalized (absolute) path. *)
  val pp_abs: Format.formatter -> t -> unit

  (** Empty filepath, used as 'dummy' for [Datatype.Filepath].
      @since 23.0-Vanadium.
  *)
  val empty: t

  (** @since 23.0-Vanadium *)
  val is_empty: t -> bool

  (** [is_special_stdout f] returns [true] iff [f] is '-' (a single dash),
      which is a special notation for 'stdout'.
      @since 23.0-Vanadium *)
  val is_special_stdout: t -> bool

  (** [is_file f] returns [true] iff [f] points to a regular file
      (or a symbolic link pointing to a file).
      Returns [false] if any errors happen when [stat]'ing the file.
      @since 22.0-Titanium *)
  val is_file: t -> bool

  (** [to_base_uri path] returns a pair [prefix, rest], according to the
      prettified value of [path]:
      - if it starts with symbolic path SYMB, prefix is Some "SYMB";
      - if it is a relative path, prefix is Some "PWD";
      - else (an absolute path), prefix is None.
        [rest] contains everything after the '/' following the prefix.
        E.g. for the path "FRAMAC_SHARE/libc/string.h", returns
        ("FRAMAC_SHARE", "libc/string.h").

      @since 22.0-Titanium
  *)
  val to_base_uri: t -> string option * string
end

(** returns true if the file is relative to [base]
    (that is, it is prefixed by [base_name]), or to the current
    working directory if no base is specified.
    @since Aluminium-20160501
    @before 23.0-Vanadium argument types were string instead of Normalized.t.
*)
val is_relative: ?base_name:Normalized.t -> Normalized.t -> bool

(** [add_symbolic_dir name dir] indicates that the (absolute) path [dir] must
    be replaced by [name] when pretty-printing paths.
    This alias ensures that system-dependent paths such as FRAMAC_SHARE are
    printed identically in different machines. *)
val add_symbolic_dir: string -> Normalized.t -> unit

val add_symbolic_dir_list: string -> Normalized.t list -> unit

(** Remove all symbolic dirs that have been added earlier.
    @since 23.0-Vanadium *)
val reset_symbolic_dirs: unit -> unit

(** Returns the list of symbolic dirs added via [add_symbolic_dir], plus
    preexisting ones (e.g. FRAMAC_SHARE), as pairs (name, dir).

    @since 22.0-Titanium
*)
val all_symbolic_dirs: unit -> (string * Normalized.t) list

(** Describes a position in a source file.
    @since 18.0-Argon
*)
type position =
  {
    pos_path : Normalized.t;
    pos_lnum : int;
    pos_bol : int;
    pos_cnum : int;
  }

(** Empty position, used as 'dummy' for [Cil_datatype.Position].
    @since 30.0-Zinc
*)
val empty_pos : position

(** Pretty-prints a position, in the format file:line.
    @since 18.0-Argon
*)
val pp_pos : Format.formatter -> position -> unit

(** Return true if the given position is the empty position.
    @since 30.0-Zinc
*)
val is_empty_pos : position -> bool

(** Return the current working directory.
    Implicitly uses {!Unix.realpath} to normalize paths and avoid issues with
    symbolic links in directory names.

    @since 25.0-Manganese
    @before 28.0-Nickel return type was string instead of Normalized.t.
*)
val pwd : unit -> Normalized.t

(** Equivalent to [Sys.file_exists].
    @since 28.0-Nickel
*)
val exists: Normalized.t -> bool

(** Equivalent to [Sys.is_directory].
    @since 28.0-Nickel
*)
val is_dir: Normalized.t -> bool

(** Equivalent to [Sys.readdir].
    @since 28.0-Nickel
*)
val readdir: Normalized.t -> string array

(** Equivalent to [Sys.remove].
    @since 28.0-Nickel
*)
val remove: Normalized.t -> unit

(** Equivalent to [Sys.rename].
    @since 28.0-Nickel
*)
val rename: Normalized.t -> Normalized.t -> unit

(** Equivalent to [Filename.basename].
    @since 28.0-Nickel
*)
val basename: Normalized.t -> string

(** Equivalent to [Filename.dirname].
    @since 28.0-Nickel
*)
val dirname: Normalized.t -> Normalized.t

(** This type defines what action {!with_in} and {!with_out} must perform when
    the file to open does not exist. *)
type action_if_missing =
  | Create of int (** create the file with the given permissions *)
  | DoNotCreate (** do not create the file and fail *)

(** This type define what action [with_out] must perform when the file to
    open already exists. *)
type action_if_exists =
  | Error (** file opening functions will fail with an error *)
  | Append (** the writing contents will be appended *)
  | Truncate (** the file will be truncated before any writes *)

(** [with_in path f] opens file [path] for reading and calls [f] with the
    newly-created input channel. The file is closed when [f] returns or whenever
    an exception is thrown by [f].
    @param if_missing defines what must be done if the file does not exist,
    defaults to [DoNotCreate].
    @param binary must be set if the file needs to be opened in binary mode
    (disables conversion, e.g. new lines), defaults to [false]
    @param blocking must be unset if the file needs to be opened in nonblocking
    mode, defaults to [true].
    @return [Ok (f input_channel)] if no exceptions are thrown, or [Error s]
    if a [Sys_error s] is thrown during the execution of [f] or during the
    closing of the file.
    @since Frama-C+dev
*)
val with_in:
  ?if_missing:action_if_missing -> ?binary:bool -> ?blocking:bool ->
  Normalized.t -> (in_channel -> 'a) -> ('a,string) result

(** Same as {!with_in} but raises [Sys_error] instead of returning [Error].
    @since Frama-C+dev
*)
val with_in_exn :
  ?if_missing:action_if_missing -> ?binary:bool -> ?blocking:bool ->
  Normalized.t -> (in_channel -> 'a) -> 'a

(** [with_out path f] calls [f] with a new output channel on the file [path]
    opened for writing. The file is closed when [f] returns or whenever an
    exception is thrown by [f].
    @param if_missing defines what must be done if the file does not exist,
    defaults to [Create 0o666].
    @param if_exists defines what action must be performed when the file already
    exists, defaults to [Truncate].
    @param binary must be set if the file needs to be opened in binary mode
    (disables conversion, e.g. new lines), defaults to [false].
    @param blocking must be unset if the file needs to be opened in nonblocking
    mode, defaults to [true].

    @return [Ok (f output_channel)] if no exceptions are thrown, or [Error s]
    if a [Sys_error s] is thrown during the execution of [f] or during the
    closing the file.
    @since Frama-C+dev
*)
val with_out:
  ?if_missing:action_if_missing -> ?if_exists:action_if_exists ->
  ?binary:bool -> ?blocking:bool ->
  Normalized.t -> (out_channel -> 'a) -> ('a,string) result

(** Same as {!with_out} but raises [Sys_error] instead of returning [Error].
    @since Frama-C+dev
*)
val with_out_exn:
  ?if_missing:action_if_missing -> ?if_exists:action_if_exists ->
  ?binary:bool -> ?blocking:bool ->
  Normalized.t -> (out_channel -> 'a) -> 'a

(** Opening this module allows to use shorter syntax to deal with files.

    {[
      let open Filepath.Operators in
      let& error =
        let+$ channel = open_out filepath in
        output_string channel "42";
      in
      Format.printf "error writing to file %a: %s"
        Filepath.Normalized.pretty filepath
        error
    ]}

    When the file processing returns a result by itself, the operator [let*$]
    can be used instead:

    {[
      let open Filepath.Operators in
      let*$ channel = open_in filepath in
      try
        let header = input_line channel in
        if header = "42"
        then Ok ()
        else Error "wrong file header"
      with End_of_file ->
        Error "file is empty"
    ]}
*)
module Operators : sig
  type ('ch,'a) safe_processor
  type ('ch,'a) exn_processor

  val open_in:
    ?if_missing:action_if_missing -> ?binary:bool -> ?blocking:bool ->
    Normalized.t -> (in_channel,'a) safe_processor
  val open_in_exn:
    ?if_missing:action_if_missing -> ?binary:bool -> ?blocking:bool ->
    Normalized.t -> (in_channel,'a) exn_processor
  val open_out:
    ?if_missing:action_if_missing -> ?if_exists:action_if_exists ->
    ?binary:bool -> ?blocking:bool ->
    Normalized.t -> (out_channel,'a) safe_processor
  val open_out_exn:
    ?if_missing:action_if_missing -> ?if_exists:action_if_exists ->
    ?binary:bool -> ?blocking:bool ->
    Normalized.t -> (out_channel,'a) exn_processor

  (** {3 Result operators}
      These operators are intended to be used with {!open_in} or {!open_out}.
  *)

  val (let+$): ('ch,'a) safe_processor -> ('ch -> 'a) -> ('a,string) result
  val (let*$):
    ('ch,('a,string) result) safe_processor ->
    ('ch -> ('a,string) result) ->
    ('a,string) result

  (** {3 Exception operators}
      These operators are intended to be used with {!open_in_exn} or
      {!open_out_exn}, error [Sys_error] must be caught.
  *)

  val (let$): ('ch,'a) exn_processor -> ('ch -> 'a) -> 'a

  (** {3 Error handling}
      These operators can be used to handle result errors.
  *)

  val (let&): (unit,'e) result -> ('e -> unit) -> unit
  val (let+&): ('a,'e) result -> ('e -> 'a) ->  ('a,'e) result
  val (let*&): ('a,'e) result -> ('e -> ('a,'e) result) -> ('a,'e) result
end

(*
  Local Variables:
  compile-command: "make -C ../../.."
  End:
*)
