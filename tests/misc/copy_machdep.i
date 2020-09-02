/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs} -machdep x86_64 -enums int -no-unicode
*/

int main () { return 0; }
