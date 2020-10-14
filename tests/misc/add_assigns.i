/* run.config
PLUGIN: report @EVA_PLUGINS@
MODULE: @PTEST_NAME@.cmxs
OPT: -then -report -then -print
*/

/*@ assigns *x; */
int f(int* x, int* y) {
  *x++;
  *y++;
  return *x + *y;
}
