/* run.config
   MODULE: @PTEST_NAME@.cmxs
   OPT: @EVA_CONFIG@
*/

int* f() {
  int x;
  return &x;
}

void main(int x) {
  int *p = f();
  *p = 1;
}
