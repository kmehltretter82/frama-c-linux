/* run.config
EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
OPT: -print -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs tests/syntax/formals_decl_leak_1.i
*/

void f(int x);

void g() { f(3); }
