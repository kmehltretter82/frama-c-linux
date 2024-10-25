(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(** Managing machine-dependent information. *)

(* ***********************************************************************)
(** {2 Machdep}                                                          *)
(* ***********************************************************************)

(** Definition of a machine model (architecture + compiler).
    @see <https://frama-c.com/download/frama-c-plugin-development-guide.pdf> *)
type mach = {
  sizeof_short: int;      (** [sizeof(short)] *)
  sizeof_int: int;        (** [sizeof(int)] *)
  sizeof_long: int ;      (** [sizeof(long)] *)
  sizeof_longlong: int;   (** [sizeof(long long)] *)
  sizeof_ptr: int;        (** [sizeof(<pointer type>)] *)
  sizeof_float: int;      (** [sizeof(float)] *)
  sizeof_double: int;     (** [sizeof(double)] *)
  sizeof_longdouble: int; (** [sizeof(long double)] *)
  sizeof_void: int;       (** [sizeof(void)] *)
  sizeof_fun: int;        (** [sizeof(<function type>)]. Negative if unsupported. *)
  size_t: string;         (** Type of [sizeof(<type>)] *)
  ssize_t: string;        (** representation of ssize_t *)
  wchar_t: string;        (** Type of "wchar_t" *)
  ptrdiff_t: string;      (** Type of "ptrdiff_t" *)
  intptr_t: string;       (** Type of "intptr_t" *)
  uintptr_t: string;      (** Type of "uintptr_t" *)
  int_fast8_t: string;    (** Type of "int_fast8_t" *)
  int_fast16_t: string;   (** Type of "int_fast16_t" *)
  int_fast32_t: string;   (** Type of "int_fast32_t" *)
  int_fast64_t: string;   (** Type of "int_fast64_t" *)
  uint_fast8_t: string;   (** Type of "uint_fast8_t" *)
  uint_fast16_t: string;  (** Type of "uint_fast16_t" *)
  uint_fast32_t: string;  (** Type of "uint_fast32_t" *)
  uint_fast64_t: string;  (** Type of "uint_fast64_t" *)
  wint_t: string;         (** Type of "wint_t" *)
  sig_atomic_t: string;   (** Type of "sig_atomic_t" *)
  time_t: string;         (** Type of "time_t" *)
  alignof_short: int;     (** [_AlignOf(short)] *)
  alignof_int: int;       (** [_AlignOf(int)] *)
  alignof_long: int;      (** [_AlignOf(long)] *)
  alignof_longlong: int;  (** [_AlignOf(long long)] *)
  alignof_ptr: int;       (** [_AlignOf(<pointer type>)] *)
  alignof_float: int;     (** [_AlignOf(float)] *)
  alignof_double: int;    (** [_AlignOf(double)] *)
  alignof_longdouble: int; (** [_AlignOf(long double)] *)
  alignof_str: int;       (** [_AlignOf(<string>)] *)
  alignof_fun: int;       (** [_AlignOf(<function type>)]. Negative if unsupported. *)
  alignof_aligned: int;   (** Alignment of a type with aligned attribute *)
  char_is_unsigned: bool; (** Whether "char" is unsigned *)
  little_endian: bool;    (** whether the machine is little endian *)
  has__builtin_va_list: bool; (** Whether [__builtin_va_list] is a known type *)
  (** Compiler being used. Currently recognized names are 'gcc', 'msvc' and 'generic'. *)
  compiler: string;
  (** Architecture-specific flags to be given to the preprocessor (if supported) *)
  cpp_arch_flags: string list;
  version: string;        (** Information on this machdep *)
  weof: string;           (** expansion of WEOF macro, empty if undefined *)
  wordsize: string;       (** expansion of __WORDSIZE macro, empty if undefined *)
  posix_version: string;  (** expansion of _POSIX_VERSION macro, empty if undefined *)
  bufsiz: string;         (** expansion of BUFSIZ macro *)
  eof: string;            (** expansion of EOF macro *)
  fopen_max: string;      (** expansion of FOPEN_MAX macro *)
  filename_max: string;   (** expansion of FILENAME_MAX macro *)
  host_name_max: string;  (** expansion of HOST_NAME_MAX macro *)
  tty_name_max: string;   (** expansion of TTY_NAME_MAX macro *)
  l_tmpnam: string;       (** expansion of L_tmpnam macro *)
  path_max: string;       (** expansion of PATH_MAX macro *)
  tmp_max: string;        (** expansion of TMP_MAX macro *)
  rand_max: string;       (** expansion of RAND_MAX macro *)
  mb_cur_max: string;     (** expansion of MB_CUR_MAX macro *)
  nsig: string;           (** expansion of non-standard NSIG macro, empty if undefined *)
  errno: (string * string) list; (** list of macros defining errors in errno.h*)
  machdep_name: string; (** name of the machdep *)
  custom_defs: (string * string) list; (** sequence of key/value for C macros *)
} [@@deriving yaml]
(** @since 30.0-Zinc  *)

module Machdep: Datatype.S_with_collections with type t = mach
(** @since 30.0-Zinc  *)

(* ***********************************************************************)
(** {2 Compiler }                                                        *)
(* ***********************************************************************)

val msvcMode: mach -> bool
(** Short for [machdep.compiler = "msvc"]
    @since 30.0-Zinc  *)

val gccMode: mach -> bool
(** Short for [machdep.compiler = "gcc"]
    @since 30.0-Zinc  *)

val allowed_machdep: string -> string
(** [allowed_machdep "machdep family"] provides a standard message for features
    only allowed for a particular machdep.
    @since 30.0-Zinc  *)

(* ***********************************************************************)
(** {2 Generation }                                                      *)
(* ***********************************************************************)

(** Prints on the given formatter all [#define] directives
    required by [share/libc/features.h] and other system-dependent headers.
    @param censored_macros prevents the generation of directives for the
    builtin macros in [mach.custom_defs] whose names match. empty by default.
    @before 29.0-Copper censored_macros did not exist
*)
val gen_all_defines:
  Format.formatter -> ?censored_macros:Datatype.String.Set.t -> mach -> unit

(** generates a [__fc_machdep.h] file in a temp directory and returns the
    directory name, to be added to the search path for preprocessing stdlib.
    @param see {!gen_all_defines}
    @before 29.0-Copper censored_macros did not exist.
*)
val generate_machdep_header:
  ?censored_macros:Datatype.String.Set.t -> mach -> Filepath.Normalized.t
