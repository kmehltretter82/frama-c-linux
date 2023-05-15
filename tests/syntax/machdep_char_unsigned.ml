open Cil_types

let md = {
  version          = "";
  compiler = "gcc";
  cpp_arch_flags = ["-m32"];
  sizeof_short     = 2;
  sizeof_int       = 2;
  sizeof_long      = 4;
  sizeof_longlong  = 8;
  sizeof_ptr       = 4;
  sizeof_float     = 4;
  sizeof_double    = 8;
  sizeof_longdouble  = 8;
  sizeof_void      = -1;
  sizeof_fun       = 0;
  alignof_short = 2;
  alignof_int = 2;
  alignof_long = 2;
  alignof_longlong = 2;
  alignof_ptr = 2;
  alignof_float = 2;
  alignof_double = 2;
  alignof_longdouble = 2;
  alignof_str = 0;
  alignof_fun = 0;
  alignof_aligned= 0;
  char_is_unsigned = true;
  little_endian = true;
  size_t = "unsigned int";
  ssize_t = "int";
  wchar_t = "int";
  intptr_t = "int";
  uintptr_t = "unsigned int";
  int_fast8_t = "signed char";
  int_fast16_t = "long";
  int_fast32_t = "long";
  int_fast64_t = "long";
  uint_fast8_t = "unsigned char";
  uint_fast16_t = "unsigned long";
  uint_fast32_t = "unsigned long";
  uint_fast64_t = "usigned long";
  ptrdiff_t = "int";
  wint_t = "long";
  sig_atomic_t = "int";
  time_t = "long";
  has__builtin_va_list = true;
  weof = "(-1L)";
  wordsize = "16";
  posix_version = "";
  bufsiz = "8192";
  eof = "(-1)";
  fopen_max = "16";
  host_name_max = "255";
  tty_name_max = "255";
  path_max = "255";
  filename_max = "2048";
  l_tmpnam = "2048";
  tmp_max = "0xFFFFFFFF";
  rand_max = "0xFFFFFFFE";
  mb_cur_max = "16";
  nsig = "64";
  errno = [
    "edom", "33";
    "eilseq", "84";
    "erange", "34";
  ];
  machdep_name = "machdep_char_unsigned";
  custom_defs = "";
}

let () =
  File.new_machdep "unsigned_char" md
