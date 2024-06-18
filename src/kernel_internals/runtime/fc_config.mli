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

(** Information about version of Frama-C.
    The body of this module is generated from Makefile. *)

val version: string
(** Frama-C Version identifier. *)

val codename: string
(** Frama-C version codename.
    @since 18.0-Argon *)

val version_and_codename: string
(** Frama-C version and codename.
    @since 18.0-Argon *)

val major_version: int
(** Frama-C major version number.
    @since 19.0-Potassium *)

val minor_version: int
(** Frama-C minor version number.
    @since 19.0-Potassium *)

val is_gui: bool
(** Is the Frama-C GUI running?
      @since Beryllium-20090601-beta1
      @since frama-c-trunk not anymore a reference
*)

val datadirs: Filepath.Normalized.t list
(** Directories where architecture independent files are in order of
    priority.
    @since 19.0-Potassium *)

val datadir: Filepath.Normalized.t
(** Last directory of datadirs (the directory of frama-c installation)
    @since 19.0-Potassium *)

val framac_libc: Filepath.Normalized.t
(** Directory where Frama-C libc headers are.
    @since 19.0-Potassium *)

val libdirs: Filepath.Normalized.t list
(** Directories where library and executable files are, in order of
    priority.
    @since 26.0-Iron *)

val libdir: Filepath.Normalized.t
(** Last directory of libdirs (the directory of frama-c installation)
    @since 26.0-Iron *)

val plugin_dir: Filepath.Normalized.t list
(** Directory where the Frama-C dynamic plug-ins are. *)

val plugin_path: string
(** The colon-separated concatenation of [plugin_dir].
    @since Magnesium-20151001 *)

val preprocessor: string
(** Name of the default command to call the preprocessor.
    If the CPP environment variable is set, use it
    else use the built-in default from autoconf. Usually this is
    "gcc -C -E -I."
    @since Oxygen-20120901 *)

val using_default_cpp: bool
(** whether the preprocessor command is the one defined at configure time
    or the result of taking a CPP environment variable, in case it differs
    from the configure-time command.

    @since Phosphorus-20170501-beta1 *)

val preprocessor_is_gnu_like: bool
(** whether the default preprocessor accepts the same options as gcc
    (i.e. is either gcc or clang), when this is the case, the default
    command line for preprocessing contains more options.
    @since Sodium-20150201
*)

val preprocessor_supported_arch_options: string list
(** architecture-related options (e.g. -m32) known to be supported by
    the default preprocessor. Used to match preprocessor commands to
    selected machdeps.
    @since Phosphorus-20170501-beta1
*)

val preprocessor_keep_comments: bool
(** [true] if the default preprocessor selected during compilation is
    able to keep comments (hence ACSL annotations) in its output.
    @since Neon-rc3
*)

(*
  Local Variables:
  compile-command: "make -C ../../.."
  End:
*)
