/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/

int f(int x) { return x; }

int g(int x) { return x; }
