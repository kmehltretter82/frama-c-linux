/* run.config*
CMXS: @PTEST_NAME@
OPT: -eva -main f -load-module %{dep:@PTEST_NAME@.cmxs} -then-on change_main -main g -eva
*/

int f(int x) { return x; }
