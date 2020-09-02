/* run.config
   CMXS: @PTEST_NAME@
   OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/

int f(int x);

int main () { return f(0); }
