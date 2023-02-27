open Cil_types

let gen_define fmt macro pp def =
  Format.fprintf fmt "#define %s %a@\n" macro pp def

let gen_define_string fmt macro def =
  gen_define fmt macro Format.pp_print_string def

let gen_byte_order fmt mach =
  gen_define_string fmt "__FC_BYTE_ORDER"
    (if mach.little_endian then "__LITTLE_ENDIAN" else "__BIG_ENDIAN")

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
    "long long", "ll";
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

let gen_define_printing_prefix fmt name kind =
  gen_define_string fmt
    ("__PRI" ^ name ^ "_PREFIX")
    (List.assoc kind pp_of_kind)

let existing_int_size mach =
  [ 1, "char";
    mach.sizeof_short, "short";
    mach.sizeof_int, "int";
    mach.sizeof_long, "long";
    mach.sizeof_longlong, "long long"]

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
        gen_int_type_family fmt ("_LEAST" ^ string_of_int bitsize) bitsize kind;
        gen_int_type_family fmt ("_FAST" ^ string_of_int bitsize) bitsize kind

let gen_max_size_int fmt mach =
  gen_int_type_family fmt "MAX" (8 * mach.sizeof_longlong) "long long"

let gen_all_defines fmt mach =
  Format.fprintf fmt "/* Machdep-specific info for Frama-C's libc */@\n";
  Format.fprintf fmt "#ifndef __FC_MACHDEP@\n#define __FC_MACHDEP@\n";
  gen_byte_order fmt mach;
  (* TODO: __FC_POSIX_VERSION *)
  gen_fixed_size_family fmt 8 mach;
  gen_fixed_size_family fmt 16 mach;
  gen_fixed_size_family fmt 32 mach;
  gen_fixed_size_family fmt 64 mach;
  gen_max_size_int fmt mach;
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
