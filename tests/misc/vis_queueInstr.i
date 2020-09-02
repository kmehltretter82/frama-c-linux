/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs} -print -then-on A -print
*/

int main(){
  int i = 0;
}
