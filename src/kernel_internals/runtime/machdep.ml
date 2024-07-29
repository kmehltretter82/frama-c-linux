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

let yaml_dict_to_list = function
  | `O l ->
    let make_one acc (k,v) =
      Result.(
        bind acc
          (fun l ->
             match Yaml.Util.to_string v with
             | Ok s -> Ok((k,s) :: l)
             | Error (`Msg s) ->
               Error (`Msg ("Unexpected value for key " ^ k ^ ": " ^ s))))
    in
    List.fold_left make_one (Ok []) l
  | _ -> Error (`Msg "Unexpected YAML value instead of dictionary of strings")

type mach = {
  sizeof_short: int;
  sizeof_int: int;
  sizeof_long: int;
  sizeof_longlong: int;
  sizeof_ptr: int;
  sizeof_float: int;
  sizeof_double: int;
  sizeof_longdouble: int;
  sizeof_void: int;
  sizeof_fun: int;
  size_t: string;
  ssize_t: string;
  wchar_t: string;
  ptrdiff_t: string;
  intptr_t: string;
  uintptr_t: string;
  int_fast8_t: string;
  int_fast16_t: string;
  int_fast32_t: string;
  int_fast64_t: string;
  uint_fast8_t: string;
  uint_fast16_t: string;
  uint_fast32_t: string;
  uint_fast64_t: string;
  wint_t: string;
  sig_atomic_t: string;
  time_t: string;
  alignof_short: int;
  alignof_int: int;
  alignof_long: int;
  alignof_longlong: int;
  alignof_ptr: int;
  alignof_float: int;
  alignof_double: int;
  alignof_longdouble: int;
  alignof_str: int;
  alignof_fun: int;
  alignof_aligned: int;
  char_is_unsigned: bool;
  little_endian: bool;
  has__builtin_va_list: bool;
  compiler: string;
  cpp_arch_flags: string list;
  version: string;
  weof: string;
  wordsize: string;
  posix_version: string;
  bufsiz: string;
  eof: string;
  fopen_max: string;
  filename_max: string;
  host_name_max: string;
  tty_name_max: string;
  l_tmpnam: string;
  path_max: string;
  tmp_max: string;
  rand_max: string;
  mb_cur_max: string;
  nsig: string;
  errno: (string * string) list  [@of_yaml yaml_dict_to_list];
  machdep_name: string;
  custom_defs: (string * string) list [@of_yaml yaml_dict_to_list];
} [@@deriving yaml]

let dummy = {
  sizeof_short = 2;
  sizeof_int = 4;
  sizeof_long = 8;
  sizeof_longlong = 8;
  sizeof_ptr = 8;
  sizeof_float = 4;
  sizeof_double = 8;
  sizeof_longdouble = 16;
  sizeof_void = -1;
  sizeof_fun = -1;
  size_t = "unsigned long";
  ssize_t = "long";
  wchar_t = "int";
  ptrdiff_t = "long";
  intptr_t = "long";
  uintptr_t = "unsigned long";
  int_fast8_t = "signed char";
  int_fast16_t = "long";
  int_fast32_t = "long";
  int_fast64_t = "long";
  uint_fast8_t = "unsigned char";
  uint_fast16_t = "unsigned long";
  uint_fast32_t = "unsigned long";
  uint_fast64_t = "unsigned long";
  wint_t = "int";
  sig_atomic_t = "int";
  time_t = "long";
  alignof_short = 2;
  alignof_int = 4;
  alignof_long = 8;
  alignof_longlong = 8;
  alignof_ptr = 8;
  alignof_float = 4;
  alignof_double = 8;
  alignof_longdouble = 16;
  alignof_str = 1;
  alignof_fun = -1;
  alignof_aligned = 16;
  char_is_unsigned = true;
  little_endian = true;
  has__builtin_va_list = true;
  compiler = "none";
  cpp_arch_flags = [];
  version = "N/A";
  weof = "(-1)";
  wordsize = "64";
  posix_version = "";
  bufsiz = "255";
  eof = "(-1)";
  fopen_max = "255";
  filename_max = "4095";
  path_max = "256";
  tty_name_max = "255";
  host_name_max = "255";
  l_tmpnam = "63";
  tmp_max = "1024";
  rand_max = "0xFFFFFFFE";
  mb_cur_max = "16";
  nsig = "";
  errno = [
    "edom", "33";
    "eilseq", "84";
    "erange", "34";
  ];
  machdep_name = "dummy";
  custom_defs = [];
}

module Machdep = struct

  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined
      type t = mach
      let name = "Machdep"
      let reprs = [dummy]
      let compare: t -> t -> int = Stdlib.compare
      let equal: t -> t -> bool = (=)
      let hash: t -> int = Hashtbl.hash
      let copy = Datatype.identity
    end)

  let pretty fmt mach =
    let open Format in
    let pp_pair fmt (a, b) = fprintf fmt "(%s, %s)" a b in
    fprintf fmt
      "{sizeof_short=%d;sizeof_int=%d;sizeof_long=%d;sizeof_longlong=%d;\
       sizeof_ptr=%d;sizeof_float=%d;sizeof_double=%d;sizeof_longdouble=%d;\
       sizeof_void=%d;sizeof_fun=%d;size_t=%s;ssize_t=%s;wchar_t=%s;
       ptrdiff_t=%s;intptr_t=%s;uintptr_t=%s;\
       int_fast8_t=%s;int_fast16_t=%s;int_fast32_t=%s;int_fast64_t=%s;\
       uint_fast8_t=%s;uint_fast16_t=%s;uint_fast32_t=%s;uint_fast64_t=%s;\
       wint_t=%s;sig_atomic_t=%s;time_t=%s;\
       alignof_short=%d;alignof_int=%d;alignof_long=%d;alignof_longlong=%d;\
       alignof_ptr=%d;alignof_float=%d;alignof_double=%d;alignof_longdouble=%d;\
       alignof_str=%d;alignof_fun=%d;alignof_aligned=%d;\
       char_is_unsigned=%b;little_endian=%b;has__builtin_va_list=%b;
       compiler=%s;cpp_arch_flags=%a;version=%s;weof=%s;wordsize=%s;
       posix_version=%s;bufsiz=%s;eof=%s;fopen_max=%s;filename_max=%s;
       path_max=%s;tty_name_max=%s;host_name_max=%s;l_tmpnam=%s;tmp_max=%s;\
       rand_max=%s;mb_cur_max=%s;nsig=%s;errno=%a;machdep_name=%s;custom_defs=%a}"
      mach.sizeof_short
      mach.sizeof_int
      mach.sizeof_long
      mach.sizeof_longlong
      mach.sizeof_ptr
      mach.sizeof_float
      mach.sizeof_double
      mach.sizeof_longdouble
      mach.sizeof_void
      mach.sizeof_fun
      mach.size_t
      mach.ssize_t
      mach.wchar_t
      mach.ptrdiff_t
      mach.intptr_t
      mach.uintptr_t
      mach.int_fast8_t
      mach.int_fast16_t
      mach.int_fast32_t
      mach.int_fast64_t
      mach.uint_fast8_t
      mach.uint_fast16_t
      mach.uint_fast32_t
      mach.uint_fast64_t
      mach.wint_t
      mach.sig_atomic_t
      mach.time_t
      mach.alignof_short
      mach.alignof_int
      mach.alignof_long
      mach.alignof_longlong
      mach.alignof_ptr
      mach.alignof_float
      mach.alignof_double
      mach.alignof_longdouble
      mach.alignof_str
      mach.alignof_fun
      mach.alignof_aligned
      mach.char_is_unsigned
      mach.little_endian
      mach.has__builtin_va_list
      mach.compiler
      (pp_print_list pp_print_string) mach.cpp_arch_flags
      mach.version
      mach.weof
      mach.wordsize
      mach.posix_version
      mach.bufsiz
      mach.eof
      mach.fopen_max
      mach.filename_max
      mach.path_max
      mach.tty_name_max
      mach.host_name_max
      mach.l_tmpnam
      mach.tmp_max
      mach.rand_max
      mach.mb_cur_max
      mach.nsig
      (pp_print_list pp_pair) mach.errno
      mach.machdep_name
      (pp_print_list pp_pair) mach.custom_defs
end

let msvcMode machdep = machdep.compiler = "msvc"
let gccMode machdep = machdep.compiler = "gcc" || machdep.compiler = "clang"

let allowed_machdep machdep =
  Format.asprintf
    "only allowed for %s machdeps; see option -machdep or \
     run 'frama-c -machdep help' for the list of available machdeps"
    machdep

let gen_define fmt macro pp def =
  Format.fprintf fmt "#define %s %a@\n" macro pp def

let gen_include fmt file =
  Format.fprintf fmt "#include <%s>@\n" file

let gen_undef fmt macro =
  let macro =
    match String.index_from_opt macro 0 '(' with
    | None -> macro
    | Some n -> String.sub macro 0 n
  in
  Format.fprintf fmt "#undef %s@\n" macro

let gen_define_string fmt macro def =
  gen_define fmt macro Format.pp_print_string def

let gen_define_literal_string fmt macro def =
  gen_define fmt macro Format.pp_print_string ("\"" ^ def ^ "\"")

let gen_define_macro fmt macro def =
  if def = "" then gen_undef fmt macro
  else gen_define_string fmt macro def

let gen_define_custom_macros fmt censored key_values =
  List.iter
    (fun (k,v) ->
       if not (Datatype.String.Set.mem (Extlib.strip_underscore k) censored)
       then begin
         gen_undef fmt k;
         gen_define_macro fmt k v
       end)
    key_values

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

let gen_precise_size_type fmt mach =
  let open struct type ty = CHAR | SHORT | INT | LONG | LONGLONG end in
  let all = [CHAR; SHORT; INT; LONG; LONGLONG] in
  let size_of_ty t =
    match t with
    | CHAR -> 1
    | SHORT -> mach.sizeof_short
    | INT -> mach.sizeof_int
    | LONG -> mach.sizeof_long
    | LONGLONG -> mach.sizeof_longlong
  in
  let suffix_of_ty is_signed t =
    let suff = try
        List.assoc
          (match t with
           | CHAR -> "char"
           | SHORT -> "short"
           | INT -> "int"
           | LONG -> "long"
           | LONGLONG -> "long long") suff_of_kind
      with Not_found -> Kernel.fatal "Undefined suffix type"
    in
    let suff = (if is_signed then "" else "U")^suff in
    if suff = "" then "" else "## "^suff
  in
  let suffix is_signed n =
    let t =
      try
        List.find (fun i -> size_of_ty i * 8 == n) all
      with Not_found -> LONGLONG in
    suffix_of_ty is_signed t
  in
  gen_define_string fmt "INT8_C(c)"   ("(c"^(suffix true   8)^")");
  gen_define_string fmt "INT16_C(c)"  ("(c"^(suffix true  16)^")");
  gen_define_string fmt "INT32_C(c)"  ("(c"^(suffix true  32)^")");
  gen_define_string fmt "INT64_C(c)"  ("(c"^(suffix true  64)^")");
  gen_define_string fmt "UINT8_C(c)"  ("(c"^(suffix false  8)^")");
  gen_define_string fmt "UINT16_C(c)" ("(c"^(suffix false 16)^")");
  gen_define_string fmt "UINT32_C(c)" ("(c"^(suffix false 32)^")");
  gen_define_string fmt "UINT64_C(c)" ("(c"^(suffix false 64)^")")

let max_val bitsize is_signed kind =
  let suff = List.assoc kind suff_of_kind in
  let suff = if is_signed then suff else "U" ^ suff in
  let to_shift = if is_signed then bitsize - 1 else bitsize in
  let v = Z.(to_string (sub (shift_left one to_shift) one)) in
  v ^ suff

let min_val bitsize kind =
  let suff = List.assoc kind suff_of_kind in
  "(-" ^ (max_val bitsize true kind) ^ " - 1" ^ suff ^")"

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
  if repr <> "" then begin
    let macro = name ^ "_MIN" in
    let repr_name, is_signed = List.assoc repr (std_type_name mach) in
    if is_signed then gen_define_string fmt macro ("__FC_" ^ repr_name ^ "_MIN")
    else gen_define_int fmt macro 0
  end

let gen_intlike_max fmt name repr mach =
  if repr <> "" then begin
    let macro = name ^ "_MAX" in
    let repr_name, _ = List.assoc repr (std_type_name mach) in
    gen_define_string fmt macro ("__FC_" ^ repr_name ^ "_MAX")
  end

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

let machdep_macro_name s =
  let tr = function
    | c when 'a' <= c && c <= 'z' -> Char.uppercase_ascii c
    | c when 'A' <= c && c <= 'Z' -> c
    | c when '0' <= c && c <= '9' -> c
    | _ -> '_'
  in
  String.map tr s

let gen_all_defines fmt ?(censored_macros=Datatype.String.Set.empty) mach =
  Format.fprintf fmt "/* Machdep-specific info for Frama-C's libc */@\n";
  Format.fprintf fmt "#ifndef __FC_MACHDEP@\n#define __FC_MACHDEP@\n";
  gen_define_int fmt ("__FC_" ^ (machdep_macro_name mach.machdep_name)) 1;
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
  gen_precise_size_type fmt mach;
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
  gen_define_macro fmt "__WORDSIZE" mach.wordsize;
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
  gen_define_macro fmt "__FC_PATH_MAX" mach.path_max;
  gen_define_macro fmt "__FC_HOST_NAME_MAX" mach.host_name_max;
  gen_define_macro fmt "__FC_TTY_NAME_MAX" mach.tty_name_max;
  List.iter (gen_define_errno_macro fmt) mach.errno;
  gen_define_macro fmt "__FC_TIME_T" mach.time_t;
  gen_define_macro fmt "__FC_NSIG" mach.nsig;
  if gccMode mach then
    gen_include fmt "__fc_gcc_builtins.h";

  gen_define_custom_macros fmt censored_macros mach.custom_defs;

  Format.fprintf fmt "#endif // __FC_MACHDEP@\n"

let generate_machdep_header ?censored_macros mach =
  let debug = Kernel.(is_debug_key_enabled dkey_pp) in
  let temp = Extlib.temp_dir_cleanup_at_exit ~debug "__fc_machdep" in
  let file = Filepath.Normalized.concat temp "__fc_machdep.h" in
  let chan = open_out (file:>string) in
  let fmt = Format.formatter_of_out_channel chan in
  gen_all_defines fmt ?censored_macros mach;
  flush chan;
  close_out chan;
  temp
