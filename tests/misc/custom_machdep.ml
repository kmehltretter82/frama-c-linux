open Cil_types

let mach =
  {
    version          = "foo";
    compiler         = "bar";
    cpp_arch_flags   = [];
    sizeof_short     = 2;
    sizeof_int       = 3;
    sizeof_long      = 4;
    sizeof_longlong  = 8;
    sizeof_ptr       = 4;
    sizeof_float     = 4;
    sizeof_double    = 8;
    sizeof_longdouble  = 12;
    sizeof_void      = 1;
    sizeof_fun       = 1;
    size_t = "unsigned long";
    ssize_t = "long";
    intptr_t = "long";
    uintptr_t = "unsigned long";
    wint_t = "int";
    wchar_t = "int";
    ptrdiff_t = "int";
    sig_atomic_t = "int";
    alignof_short = 2;
    alignof_int = 3;
    alignof_long = 4;
    alignof_longlong = 4;
    alignof_ptr = 4;
    alignof_float = 4;
    alignof_double = 4;
    alignof_longdouble = 4;
    alignof_str = 1;
    alignof_fun = 1;
    alignof_aligned= 16;
    char_is_unsigned = false;
    little_endian = true;
    has__builtin_va_list = true;
    weof = "(-1)";
    wordsize = "24";
    posix_version = "200809L";
    bufsiz = "255";
    eof = "(-1)";
    fopen_max = "128";
    filename_max = "1023";
    l_tmpnam = "255";
    tmp_max = "4095";
    rand_max = "0xFFFFFFFE";
    mb_cur_max = "16";
  }

let mach2 = { mach with compiler = "baz" }

(* First run : register [mach] under name [custom].
   Second run :
   - register [mach] under name [custom] again. This must work.
   - then register [mach2] under name [custom]. This must result in an error.
*)
let () =
  let ran = ref false in
  Cmdline.run_after_loading_stage
    (fun () ->
       Kernel.result "Registering machdep 'mach' as 'custom'";
       File.new_machdep "custom" mach;
       if !ran then begin
         Kernel.result "Trying to register machdep 'mach2' as 'custom'";
         File.new_machdep "custom" mach2
       end
       else ran := true
    )
