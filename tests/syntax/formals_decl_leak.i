/* run.config
 MODULE: @PTEST_NAME@
   OPT: -print -no-autoload-plugins @PTEST_DIR@/@PTEST_NAME@_1.i
*/

void f(int x);

void g() { f(3); }
