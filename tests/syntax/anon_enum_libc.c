/* run.config
<<<<<<< HEAD
DEPS: anon_enum_libc.h
FILTER: sed -e 's|#include *"\([^/]*[/]\)*\([^/]*\)"|#include "PTESTS_DIR/\2"|'
OPT: -cpp-extra-args="-I ." -ocode ocode_@PTEST_NUMBER@_@PTEST_NAME@.c -print -then -ocode="" ocode_@PTEST_NUMBER@_@PTEST_NAME@.c -print
||||||| ac7807782d
FILTER: sed -e 's|#include *"\([^/]*[/]\)*\([^/]*\)"|#include "PTESTS_DIR/\2"|'
OPT: -cpp-extra-args="-I @PTEST_DIR@" -ocode @PTEST_DIR@/result/@PTEST_NAME@.c -print -then -ocode="" @PTEST_DIR@/result/@PTEST_NAME@.c -print
=======

OPT: -cpp-extra-args="-I @PTEST_DIR@" -ocode @PTEST_DIR@/result/@PTEST_NAME@.c -print -then -ocode="" @PTEST_DIR@/result/@PTEST_NAME@.c -print
>>>>>>> origin/master
*/
struct { int x; float y; } s1;

enum { BLA=4, BLI=12 };

#include "anon_enum_libc.h"

int f() { return BLA + s1.x; }

int g() { return FOO + s2.t; }
