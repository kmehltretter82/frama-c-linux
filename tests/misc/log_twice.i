/* run.config
   MODULE: @PTEST_NAME@
   OPT: @EVA_OPTIONS@
*/

int* f() {
  int x;
  return &x;
}

void main(int x) {
  int *p = f();
  *p = 1;
}
