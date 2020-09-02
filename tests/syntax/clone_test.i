/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/

/*@
  requires -3 <= c <= 4;
  ensures \result >= c;
*/
int f(int c) {
  if (c>0) return c; 
  //@ assert c <= 0;
  return 0; 
}
