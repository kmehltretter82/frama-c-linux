/* run.config
   CMXS: @PTEST_NAME@
   OPT: -load-module %{dep:@PTEST_NAME@.cmxs} -keep-comments
*/

int f() {
  int x = 0;
  /* Hello, I'm the f function */
  return x;
}
