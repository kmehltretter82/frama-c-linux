/* run.config
   CMXS: @PTEST_NAME@
   OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/
void f() {
  for (int i=0; i< 10; i++);
}
