Building callgraph...
Computing data about libc/POSIX functions...
[recursion] found recursive cycle near estimate_difficulty.i:18: f -> f
Estimating difficulty for 10 function calls...
WARNING: ccosl (POSIX) has neither code nor spec in Frama-C's libc
WARNING: setjmp (POSIX) is known to be problematic for code analysis
Function-related warnings: 2
Estimating difficulty for 3 '#include <header>' directives...
WARNING: included header <complex.h> is explicitly unsupported by Frama-C
Header-related warnings: 1
Calls to dynamic allocation functions: malloc
Checking presence of unsupported C11 features...
WARNING: unsupported keyword(s) in estimate_difficulty.i: _Complex (1 line),  alignof (1 line)
WARNING: code seems to contain inline assembly ('asm(...)')
Overall difficulty score:
asm: 1
includes: 1
keywords: 2
libc: 2
malloc: 1
recursion: 1
