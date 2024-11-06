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

(** This module handle the machine configuration. Previous Frama-C
    versions handled this in {!Cil}.

    @since 30.0-Zinc
*)

open Cil_types

(* ***********************************************************************)
(** {2 State}                                                            *)
(* ***********************************************************************)

val self: State.t
(** Internal state of the machine. *)

val is_computed: ?project:Project.t -> unit -> bool
(** Whether current project has set its machine description. *)

(* ***********************************************************************)
(** {2 Sizeof getters}                                                   *)
(* ***********************************************************************)

val sizeof_short: unit -> int
val sizeof_int: unit -> int
val sizeof_long: unit -> int
val sizeof_longlong: unit -> int
val sizeof_ptr: unit -> int
val sizeof_float: unit -> int
val sizeof_double: unit -> int
val sizeof_longdouble: unit -> int
val sizeof_void: unit -> int
val sizeof_fun: unit -> int

(* ***********************************************************************)
(** {2 Names getters}                                                    *)
(* ***********************************************************************)

val size_t: unit -> string
val ssize_t: unit -> string
val wchar_t: unit -> string
val ptrdiff_t: unit -> string
val intptr_t: unit -> string
val uintptr_t: unit -> string
val int_fast8_t: unit -> string
val int_fast16_t: unit -> string
val int_fast32_t: unit -> string
val int_fast64_t: unit -> string
val uint_fast8_t: unit -> string
val uint_fast16_t: unit -> string
val uint_fast32_t: unit -> string
val uint_fast64_t: unit -> string
val wint_t: unit -> string
val sig_atomic_t: unit -> string
val time_t: unit -> string

(* ***********************************************************************)
(** {2 Alignof getters}                                                  *)
(* ***********************************************************************)

val alignof_short: unit -> int
val alignof_int: unit -> int
val alignof_long: unit -> int
val alignof_longlong: unit -> int
val alignof_ptr: unit -> int
val alignof_float: unit -> int
val alignof_double: unit -> int
val alignof_longdouble: unit -> int
val alignof_str: unit -> int
val alignof_aligned: unit -> int
val alignof_fun: unit -> int

(* ***********************************************************************)
(** {2 Typ/kind getters}                                                 *)
(* ***********************************************************************)

val ptrdiff_kind: unit -> ikind
val ptrdiff_type: unit -> typ

val sizeof_kind: unit -> ikind
val sizeof_type: unit -> typ

val wchar_kind: unit -> ikind
val wchar_type: unit -> typ

val uintptr_kind: unit -> ikind
val uintptr_type: unit -> typ

val string_literal_type: unit -> typ

(* ***********************************************************************)
(** {2 Expansions getters}                                               *)
(* ***********************************************************************)

val weof: unit -> string
val wordsize: unit -> string
val posix_version: unit -> string
val bufsiz: unit -> string
val eof: unit -> string
val fopen_max: unit -> string
val filename_max: unit -> string
val host_name_max: unit -> string
val tty_name_max: unit -> string
val l_tmpnam: unit -> string
val path_max: unit -> string
val tmp_max: unit -> string
val rand_max: unit -> string
val mb_cur_max: unit -> string
val nsig: unit -> string

(* ***********************************************************************)
(** {2 Other getters}                                                    *)
(* ***********************************************************************)

val version: unit -> string

val compiler: unit -> string

val machdep_name: unit -> string

val get_machdep: unit -> Machdep.mach

val char_is_unsigned: unit -> bool

val little_endian: unit -> bool

val has_builtin_va_list: unit -> bool

val cpp_arch_flags: unit -> string list

val errno: unit -> (string * string) list

val custom_defs: unit -> (string * string) list

val use_logical_operators: unit -> bool

val lower_constants: unit -> bool

val insert_implicit_casts: unit -> bool

(* ***********************************************************************)
(** {2 Compiler }                                                        *)
(* ***********************************************************************)

val msvcMode: unit -> bool
(** Short for [Machdep.msvcMode (get_machdep ())]
    @since 30.0-Zinc  *)

val gccMode: unit -> bool
(** Short for [Machdep.gccMode (get_machdep ())]
    @since 30.0-Zinc  *)

val acceptEmptyCompinfo: unit -> bool
(** whether we accept empty struct. Implied by {!msvcMode} and {!gccMode}, and
    can be forced by {!set_acceptEmptyCompinfo} otherwise.
    @since 30.0-Zinc
*)

val set_acceptEmptyCompinfo: unit -> unit
(** After a call to this function, empty compinfos are allowed by the kernel,
    this must be used as a configuration step equivalent to a machdep, except
    that it is not a user configuration.

    Note that if the selected machdep is GCC or MSVC, this call has no effect
    as these modes already allow empty compinfos.

    @since 30.0-Zinc
*)

(* ***********************************************************************)
(** {2 Initializer }                                                     *)
(* ***********************************************************************)

(** Call this function to perform some initialization, and only after you have
    set {!msvcMode}. {!initLogicBuiltins} is the function to call to init
    logic builtins. The [Machdep] argument is a description of the hardware
    platform and of the compiler used. *)
val init: initLogicBuiltins:(unit -> unit) -> Machdep.mach -> unit

(* ***********************************************************************)
(** {2 Forward references}                                               *)
(* ***********************************************************************)

(** Unless your name is {!Cil_builtins}, you should not call this. *)
val init_builtins_ref: (unit -> unit) ref

(* ***********************************************************************)
(** {2 Deprecated access }                                               *)
(* ***********************************************************************)

(* Prefer using previous functions *)

type machine = private
  { mutable useLogicalOperators: bool;
    (** Whether to use the logical operands LAnd and LOr. By default, do not
        use them because they are unlike other expressions and do not
        evaluate both of their operands. *)
    mutable machdep: Machdep.mach;
    (** Machine.init will set this to the current machine description. *)
    mutable lowerConstants: bool;
    (** Do lower constants (default true) *)
    mutable insertImplicitCasts: bool;
    (** Do insert implicit casts (default true) *)
    mutable stringLiteralType: typ;
    mutable upointType: typ;
    (** An unsigned integer type that fits pointers. *)
    mutable upointKind: ikind;
    (** The integer kind of {!upointType}. *)
    mutable wcharType: typ;
    (** An integer type that fits wchar_t. *)
    mutable wcharKind: ikind;
    (** The integer kind of {!wcharType}. *)
    mutable ptrdiffType: typ;
    (** An integer type that fits ptrdiff_t. *)
    mutable ptrdiffKind: ikind;
    (** The integer kind of {!ptrdiffType}. *)
    mutable typeOfSizeOf: typ;
    (** An integer type that is the type of sizeof. *)
    mutable kindOfSizeOf: ikind;
    (** The integer kind of {!typeOfSizeOf}. *)
  }

val theMachine: machine
[@@alert deprecated "Prefer using Machine functions"]

(* ***********************************************************************)
