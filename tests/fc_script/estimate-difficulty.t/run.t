  $ PTESTS_TESTING=1 frama-c-script estimate-difficulty --no-cloc estimate-difficulty.c
  Building callgraph...
  Computing data about libc/POSIX functions...
  [recursion] found recursive cycle near estimate-difficulty.c:18: f -> f
  Estimating difficulty for 10 function calls...
  WARNING: ccosl (POSIX) has neither code nor spec in Frama-C's libc
  WARNING: setjmp (POSIX) is known to be problematic for code analysis
  Function-related warnings: 2
  Estimating difficulty for 3 '#include <header>' directives...
  WARNING: included header <complex.h> is explicitly unsupported by Frama-C
  Header-related warnings: 1
  Calls to dynamic allocation functions: malloc
  WARNING: unsupported keyword(s) in estimate-difficulty.c:  _Complex (2 lines),  __int128 (1 line),  alignof (1 line)
   - _Complex is a C11 construct
   - __int128 is a non-standard construct (GNU extension)
   - alignof is a C11 construct
  WARNING: code seems to contain inline assembly ('asm(...)')
  Overall difficulty score:
  asm: 1
  includes: 1
  keywords: 3
  libc: 2
  malloc: 1
  recursion: 1
