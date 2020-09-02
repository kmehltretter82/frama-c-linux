/* run.config
CMXS: @PTEST_NAME@
OPT: -no-autoload-plugins -load-module report,@PTEST_DIR@/@PTEST_NAME@.cmxs -then -report -then -print
*/

/*@ assigns *x; */
int f(int* x, int* y) {
  *x++;
  *y++;
  return *x + *y;
}
