/* run.config
 MODULE: @PTEST_NAME@
   OPT: -no-autoload-plugins -load-module report -then -report -then -print
*/

/*@ assigns *x; */
int f(int* x, int* y) {
  *x++;
  *y++;
  return *x + *y;
}
