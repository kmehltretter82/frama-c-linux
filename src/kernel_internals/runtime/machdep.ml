(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Cil_types

let gen_define fmt macro pp def =
  Format.fprintf fmt "#define %s %a@\n" macro pp def

let gen_include fmt file =
  Format.fprintf fmt "#include <%s>@\n" file

let gen_undef fmt macro = Format.fprintf fmt "#undef %s@\n" macro

let gen_define_string fmt macro def =
  gen_define fmt macro Format.pp_print_string def

let gen_define_literal_string fmt macro def =
  gen_define fmt macro Format.pp_print_string ("\"" ^ def ^ "\"")

let gen_define_macro fmt macro def =
  if def = "" then gen_undef fmt macro
  else gen_define_string fmt macro def

let gen_define_int fmt macro def = gen_define fmt macro Format.pp_print_int def

let gen_byte_order fmt mach =
  gen_define_string fmt "__FC_BYTE_ORDER"
    (if mach.little_endian then "__LITTLE_ENDIAN" else "__BIG_ENDIAN")

let no_signedness s =
  let s = Option.value  ~default:s (Extlib.string_del_prefix "signed" s) in
  let s = Option.value  ~default:s (Extlib.string_del_prefix "unsigned" s) in
  let s = String.trim s in
  if s = "" then "int" else s

let suff_of_kind =
  [ "char", "";
    "short", "";
    "int", "";
    "long", "L";
    "long long", "LL"
  ]

let pp_of_kind =
  [ "char", "hh";
    "short", "h";
    "int", "";
    "long", "l";
    "long long", "ll"
  ]

let max_val bitsize is_signed kind =
  let suff = List.assoc kind suff_of_kind in
  let suff = if is_signed then suff else "U" ^ suff in
  let to_shift = if is_signed then bitsize - 1 else bitsize in
  let v = Z.(to_string (sub (shift_left one to_shift) one)) in
  v ^ suff

let min_val bitsize kind =
  "-" ^ (max_val bitsize true kind) ^ " - 1"

let gen_define_stype fmt name kind =
  gen_define_string fmt ("__INT" ^ name ^ "_T") ("signed " ^ kind)
let gen_define_utype fmt name kind =
  gen_define_string fmt ("__UINT" ^ name ^ "_T") ("unsigned " ^ kind)
let gen_define_min_stype fmt name bitsize kind =
  gen_define_string fmt ("__INT" ^ name ^ "_MIN") (min_val bitsize kind)
let gen_define_max_stype fmt name bitsize kind =
  gen_define_string fmt ("__INT" ^ name ^ "_MAX") (max_val bitsize true kind)
let gen_define_max_utype fmt name bitsize kind =
  gen_define_string fmt ("__UINT" ^ name ^ "_MAX") (max_val bitsize false kind)

let gen_std_signed fmt name bitsize kind =
  gen_define_string fmt ("__FC_" ^ name ^ "_MIN") (min_val bitsize kind);
  gen_define_string fmt ("__FC_" ^ name ^ "_MAX") (max_val bitsize true kind)

let gen_std_unsigned fmt name bitsize kind =
  gen_define_string fmt ("__FC_" ^ name ^ "_MAX") (max_val bitsize false kind)

let gen_define_printing_prefix fmt name kind =
  gen_define_literal_string fmt
    ("__PRI" ^ name ^ "_PREFIX")
    (List.assoc kind pp_of_kind)

let gen_sizeof fmt name size =
  gen_define_int fmt ("__SIZEOF_" ^ name) size

let existing_int_size mach =
  [ 1, "char";
    mach.sizeof_short, "short";
    mach.sizeof_int, "int";
    mach.sizeof_long, "long";
    mach.sizeof_longlong, "long long"]

let std_type_name mach =
  [ "char", if mach.char_is_unsigned then ("UCHAR", false) else ("SCHAR", true);
    "signed char", ("SCHAR", true);
    "unsigned char", ("UCHAR", false);
    "short", ("SHRT", true);
    "signed short", ("SHRT", true);
    "unsigned short", ("USHRT", false);
    "int", ("INT", true);
    "signed", ("INT", true);
    "signed int", ("INT", true);
    "unsigned", ("UINT", false);
    "unsigned int", ("UINT", false);
    "long", ("LONG", true);
    "signed long", ("LONG", true);
    "unsigned long", ("ULONG", false);
    "long long", ("LLONG", true);
    "signed long long", ("LLONG" ,true);
    "unsigned long long", ("ULLONG", false)
  ]

let gen_int_type_family fmt name bitsize kind =
  gen_define_stype fmt name kind;
  gen_define_utype fmt name kind;
  gen_define_min_stype fmt name bitsize kind;
  gen_define_max_stype fmt name bitsize kind;
  gen_define_max_utype fmt name bitsize kind;
  gen_define_printing_prefix fmt name kind

let gen_fixed_size_family fmt bitsize mach =
  let size = bitsize / 8 in
  match
    List.find_opt (fun (s,_) -> s >= size) (existing_int_size mach)
  with
  | None -> () (* No corresponding type. *)
  | Some (exact_size, kind) ->
    if size = exact_size then
      gen_int_type_family fmt (string_of_int bitsize) bitsize kind;
    gen_int_type_family fmt ("_LEAST" ^ string_of_int bitsize) bitsize kind

let gen_max_size_int fmt mach =
  gen_int_type_family fmt "MAX" (8 * mach.sizeof_longlong) "long long"

let gen_std_min_max fmt mach =
  gen_std_signed fmt "SCHAR" 8 "char";
  gen_std_unsigned fmt "UCHAR" 8 "char";
  gen_std_signed fmt "SHRT" (8*mach.sizeof_short) "short";
  gen_std_unsigned fmt "USHRT" (8*mach.sizeof_short) "short";
  gen_std_signed fmt "INT" (8*mach.sizeof_int) "int";
  gen_std_unsigned fmt "UINT" (8*mach.sizeof_int) "int";
  gen_std_signed fmt "LONG" (8*mach.sizeof_long) "long";
  gen_std_unsigned fmt "ULONG" (8*mach.sizeof_long) "long";
  gen_std_signed fmt "LLONG" (8*mach.sizeof_longlong) "long long";
  gen_std_unsigned fmt "ULLONG" (8*mach.sizeof_longlong) "long long"

let gen_va_list_repr fmt mach =
  let repr =
    if mach.has__builtin_va_list then "__builtin_va_list" else "char*"
  in
  gen_define_string fmt "__FC_VA_LIST_T" repr

let gen_char_unsigned_flag fmt mach =
  let macro = "__CHAR_UNSIGNED__" in
  if mach.char_is_unsigned then gen_define_string fmt macro "1"
  else gen_undef fmt macro

let gen_sizeof_std fmt mach =
  gen_sizeof fmt "SHORT" mach.sizeof_short;
  gen_sizeof fmt "INT" mach.sizeof_int;
  gen_sizeof fmt "LONG" mach.sizeof_long;
  gen_sizeof fmt "LONGLONG" mach.sizeof_longlong

let gen_intlike_min fmt name repr mach =
  let macro = name ^ "_MIN" in
  let repr_name, is_signed = List.assoc repr (std_type_name mach) in
  if is_signed then gen_define_string fmt macro ("__FC_" ^ repr_name ^ "_MIN")
  else gen_define_int fmt macro 0

let gen_intlike_max fmt name repr mach =
  let macro = name ^ "_MAX" in
  let repr_name, _ = List.assoc repr (std_type_name mach) in
  gen_define_string fmt macro ("__FC_" ^ repr_name ^ "_MAX")

let gen_fast_int fmt bitsize signed repr mach =
  let name = Format.sprintf "_FAST%d" bitsize in
  let full_name =
    Format.sprintf "__%sINT%s" (if signed then "" else "U") name
  in
  gen_define_string fmt (full_name ^ "_T") repr;
  if signed then gen_intlike_min fmt full_name repr mach;
  gen_intlike_max fmt full_name repr mach;
  if signed then gen_define_printing_prefix fmt name (no_signedness repr)

(* assuming all archs have an 8-bit char. In any case, if we end up dealing
   with something else at some point, machdep will not be the only place were
   changes will be required. *)
let gen_char_bit fmt _mach =
  gen_define_int fmt "__CHAR_BIT" 8

let gen_define_errno_macro fmt (name, v) =
  gen_define_string fmt ("__FC_" ^ (String.uppercase_ascii name)) v

let gen_all_defines fmt mach =
  Format.fprintf fmt "/* Machdep-specific info for Frama-C's libc */@\n";
  Format.fprintf fmt "#ifndef __FC_MACHDEP@\n#define __FC_MACHDEP@\n";
  gen_define_int fmt ("__FC_" ^ (String.uppercase_ascii mach.machdep_name)) 1;
  gen_byte_order fmt mach;
  gen_fixed_size_family fmt 8 mach;
  gen_fixed_size_family fmt 16 mach;
  gen_fixed_size_family fmt 32 mach;
  gen_fixed_size_family fmt 64 mach;
  gen_fast_int fmt 8 true mach.int_fast8_t mach;
  gen_fast_int fmt 16 true mach.int_fast16_t mach;
  gen_fast_int fmt 32 true mach.int_fast32_t mach;
  gen_fast_int fmt 64 true mach.int_fast64_t mach;
  gen_fast_int fmt 8 false mach.uint_fast8_t mach;
  gen_fast_int fmt 16 false mach.uint_fast16_t mach;
  gen_fast_int fmt 32 false mach.uint_fast32_t mach;
  gen_fast_int fmt 64 false mach.uint_fast64_t mach;
  gen_max_size_int fmt mach;
  gen_std_min_max fmt mach;
  gen_va_list_repr fmt mach;
  gen_char_unsigned_flag fmt mach;
  gen_sizeof_std fmt mach;
  gen_char_bit fmt mach;
  gen_define_string fmt "__PTRDIFF_T" mach.ptrdiff_t;
  gen_define_string fmt "__SIZE_T" mach.size_t;
  gen_define_string fmt "__WCHAR_T" mach.wchar_t;
  gen_define_string fmt "__INTPTR_T" mach.intptr_t;
  gen_define_string fmt "__UINTPTR_T" mach.uintptr_t;
  gen_define_string fmt "__PTRDIFF_T" mach.ptrdiff_t;
  gen_define_string fmt "__WINT_T" mach.wint_t;
  gen_define_string fmt "__SSIZE_T" mach.ssize_t;
  gen_intlike_max fmt "__FC_SIZE" mach.size_t mach;
  gen_intlike_min fmt "__FC_INTPTR" mach.intptr_t mach;
  gen_intlike_max fmt "__FC_INTPTR" mach.intptr_t mach;
  gen_intlike_max fmt "__FC_UINTPTR" mach.uintptr_t mach;
  gen_intlike_min fmt "__FC_WCHAR" mach.wchar_t mach;
  gen_intlike_max fmt "__FC_WCHAR" mach.wchar_t mach;
  gen_intlike_max fmt "__SSIZE" mach.ssize_t mach;
  gen_intlike_min fmt "__FC_PTRDIFF" mach.ptrdiff_t mach;
  gen_intlike_max fmt "__FC_PTRDIFF" mach.ptrdiff_t mach;
  gen_intlike_min fmt "__FC_WINT" mach.wint_t mach;
  gen_intlike_max fmt "__FC_WINT" mach.wint_t mach;
  gen_define_macro fmt "__FC_WEOF" mach.weof;
  (* NB: Frama-C's inttypes.h is assuming that intptr_t and uintptr_t have the
     same rank when it comes to define PRI.?PTR macros. *)
  gen_define_literal_string fmt "__PRIPTR_PREFIX"
    (List.assoc (no_signedness mach.intptr_t) pp_of_kind);
  gen_define_macro fmt "__FC_WORDSIZE" mach.wordsize;
  gen_define_macro fmt "__FC_POSIX_VERSION" mach.posix_version;
  gen_define_string fmt "__FC_SIG_ATOMIC_T" mach.sig_atomic_t;
  gen_intlike_min fmt "__FC_SIG_ATOMIC_MIN" mach.sig_atomic_t mach;
  gen_intlike_max fmt "__FC_SIG_ATOMIC_MAX" mach.sig_atomic_t mach;
  gen_define_macro fmt "__FC_BUFSIZ" mach.bufsiz;
  gen_define_macro fmt "__FC_EOF" mach.eof;
  gen_define_macro fmt "__FC_FOPEN_MAX" mach.fopen_max;
  gen_define_macro fmt "__FC_FILENAME_MAX" mach.filename_max;
  gen_define_macro fmt "__FC_L_tmpnam" mach.l_tmpnam;
  gen_define_macro fmt "__FC_TMP_MAX" mach.tmp_max;
  gen_define_macro fmt "__FC_RAND_MAX" mach.rand_max;
  gen_define_macro fmt "__FC_MB_CUR_MAX" mach.mb_cur_max;
  List.iter (gen_define_errno_macro fmt) mach.errno;
  gen_define_macro fmt "__FC_TIME_T" mach.time_t;
  gen_define_macro fmt "__FC_NSIG" mach.nsig;
  (* NB: should we use Cil.gccMode() here? *)
  if mach.compiler = "gcc" then
    gen_include fmt "__fc_gcc_builtins.h";

  Format.fprintf fmt "#endif // __FC_MACHDEP@\n"

let generate_machdep_header mach =
  let debug = Kernel.(is_debug_key_enabled dkey_pp) in
  let temp = Extlib.temp_dir_cleanup_at_exit ~debug "__fc_machdep" in
  let temp = Filepath.Normalized.of_string temp in
  let file = Filepath.Normalized.concat temp "__fc_machdep.h" in
  let chan = open_out (file:>string) in
  let fmt = Format.formatter_of_out_channel chan in
  gen_all_defines fmt mach;
  flush chan;
  close_out chan;
  temp
