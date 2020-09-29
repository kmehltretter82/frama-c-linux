/* run.config
PLUGIN: report
CMXS: @PTEST_NAME@
OPT: -load-module %{dep:@PTEST_NAME@.cmxs} -then -report -then -print
*/

/*@ assigns *x; */
int f(int* x, int* y) {
  *x++;
  *y++;
  return *x + *y;
}
