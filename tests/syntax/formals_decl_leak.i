/* run.config
CMXS: @PTEST_NAME@
OPT: -print -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs} @PTEST_DIR@/@PTEST_NAME@_1.i
*/

void f(int x);

void g() { f(3); }
