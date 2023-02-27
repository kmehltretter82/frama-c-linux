open Cil_types

let gen_define fmt macro pp def =
  Format.fprintf fmt "#define %s %a@\n" macro pp def

let gen_define_string fmt macro def =
  gen_define fmt macro Format.pp_print_string def

let gen_byte_order fmt mach =
  gen_define_string fmt "__FC_BYTE_ORDER"
    (if mach.little_endian then "__LITTLE_ENDIAN" else "__BIG_ENDIAN")

let gen_all_defines fmt mach =
  Format.fprintf fmt "/* Machdep-specific info for Frama-C's libc */@\n";
  Format.fprintf fmt "#ifndef __FC_MACHDEP@\n#define __FC_MACHDEP@\n";
  gen_byte_order fmt mach;
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
