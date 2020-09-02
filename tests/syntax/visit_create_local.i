/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs} -then-on bidon -print
 */
void main() { int x,y;  x = y; }
