/* run.config
DEPS: anon_enum_libc.h
FILTER: sed -e 's|#include *"\([^/]*[/]\)*\([^/]*\)"|#include "PTESTS_DIR/\2"|'
OPT: -cpp-extra-args="-I ." -ocode @PTEST_NAME@.tmp.c -print -then -ocode="" @PTEST_NAME@.tmp.c -print
*/
struct { int x; float y; } s1;

enum { BLA=4, BLI=12 };

#include "anon_enum_libc.h"

int f() { return BLA + s1.x; }

int g() { return FOO + s2.t; }
